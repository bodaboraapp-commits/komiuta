defmodule Xpressbus.GoogleMapsTest do
  use ExUnit.Case, async: false

  alias Xpressbus.GoogleMaps

  defp with_http(fun) do
    previous = Application.get_env(:xpressbus, :google_maps_http_override)
    Application.put_env(:xpressbus, :google_maps_http_override, fun)
    on_exit(fn -> restore(previous) end)
  end

  defp restore(nil), do: Application.delete_env(:xpressbus, :google_maps_http_override)
  defp restore(fun), do: Application.put_env(:xpressbus, :google_maps_http_override, fun)

  defp response(status, body, content_type \\ "application/json") do
    {:ok,
     %Req.Response{
       status: status,
       headers: %{"content-type" => content_type},
       body: body
     }}
  end

  defp referer(opts) do
    opts[:headers]
    |> List.wrap()
    |> Enum.find_value(fn {name, value} ->
      if String.downcase(to_string(name)) == "referer", do: value
    end)
  end

  describe "server key" do
    test "accepts a working Places API key" do
      with_http(fn :post, url, _opts ->
        assert url =~ "places.googleapis.com"
        response(200, %{"places" => []})
      end)

      result = GoogleMaps.validate_server_key("AIzaServerKey123")
      assert result.status == :ok
      assert result.message =~ "Places API"
    end

    test "reports a key that is still referrer-restricted" do
      with_http(fn :post, _url, _opts ->
        response(403, %{
          "error" => %{
            "status" => "PERMISSION_DENIED",
            "details" => [%{"reason" => "API_KEY_HTTP_REFERRER_BLOCKED"}]
          }
        })
      end)

      result = GoogleMaps.validate_server_key("AIzaServerKey123")
      assert result.status == :error
      assert result.message =~ "referrer-restricted"
      assert result.message =~ "None or IP addresses"
    end

    test "reports an IP restriction that blocks this server" do
      with_http(fn :post, _url, _opts ->
        response(403, %{"error" => %{"details" => [%{"reason" => "API_KEY_IP_ADDRESS_BLOCKED"}]}})
      end)

      result = GoogleMaps.validate_server_key("AIzaServerKey123")
      assert result.status == :error
      assert result.message =~ "IP restriction"
      assert result.message =~ "outbound IP"
    end

    test "rejects a missing or malformed key without a request" do
      assert %{status: :error, message: "Server key is missing."} =
               GoogleMaps.validate_server_key(nil)

      assert %{status: :error, message: message} =
               GoogleMaps.validate_server_key("not-a-google-key")

      assert message =~ "does not look like a Google API key"
    end
  end

  describe "browser key" do
    test "passes when the KOMIUTA referrer is allowed and a fake referrer is blocked" do
      with_http(fn :get, url, opts ->
        assert url =~ "staticmap"

        if referer(opts) == "https://www.komiuta.com/" do
          response(200, "", "image/png")
        else
          response(403, %{
            "error" => %{"details" => [%{"reason" => "API_KEY_HTTP_REFERRER_BLOCKED"}]}
          })
        end
      end)

      result = GoogleMaps.validate_browser_key("AIzaBrowserKey123")
      assert result.status == :ok
      assert result.message =~ "referrer-restricted"
    end

    test "warns when a browser key accepts an untrusted referrer" do
      with_http(fn :get, _url, _opts -> response(200, "", "image/png") end)

      result = GoogleMaps.validate_browser_key("AIzaBrowserKey123")
      assert result.status == :warning
      assert result.message =~ "accepts an untrusted referrer"
      assert result.message =~ "Add HTTP referrer restrictions"
    end

    test "reports a key that does not allow the KOMIUTA origin" do
      with_http(fn :get, _url, _opts ->
        response(403, %{
          "error" => %{"details" => [%{"reason" => "API_KEY_HTTP_REFERRER_BLOCKED"}]}
        })
      end)

      result = GoogleMaps.validate_browser_key("AIzaBrowserKey123")
      assert result.status == :error
      assert result.message =~ "does not allow"
      assert result.message =~ "www.komiuta.com"
    end

    test "warns when neither Static Maps nor Geocoding can be used to test the key" do
      with_http(fn :get, _url, _opts ->
        response(403, %{"error" => %{"details" => [%{"reason" => "API_KEY_SERVICE_BLOCKED"}]}})
      end)

      result = GoogleMaps.validate_browser_key("AIzaBrowserKey123")
      assert result.status == :warning
      assert result.message =~ "cannot be tested"
    end
  end

  test "test_keys returns independent browser and server results" do
    with_http(fn
      :post, _url, _opts -> response(200, %{"places" => []})
      :get, _url, _opts -> response(200, "", "image/png")
    end)

    result = GoogleMaps.test_keys("AIzaBrowserKey123", "AIzaServerKey123")

    assert result.browser.status == :warning
    assert result.server.status == :ok
  end
end
