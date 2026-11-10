defmodule Xpressbus.GoogleMaps do
  @moduledoc """
  Validates the two Google Maps Platform credentials used by KOMIUTA.

  Browser keys and server keys have different application restrictions:

    * the **browser key** must be HTTP-referrer restricted to the KOMIUTA
      origins and is used by browser map views;
    * the **server key** must be unrestricted or IP-restricted (never
      referrer-restricted) because Places and Static Maps calls originate from
      the application server.

  `test_keys/2` performs real Google requests so the admin "Test API" button
  reports what Google actually enforces instead of only checking that a key is
  present. Set `config :xpressbus, :google_maps_http_override, &fun/3` to inject
  a transport in tests; the default transport is `Req`.
  """

  @places_url "https://places.googleapis.com/v1/places:searchText"
  @geocode_url "https://maps.googleapis.com/maps/api/geocode/json"
  @static_map_url "https://maps.googleapis.com/maps/api/staticmap"

  @allowed_referer "https://www.komiuta.com/"
  @blocked_referer "https://komiuta.invalid/"

  @type result :: %{
          status: :ok | :warning | :error,
          ok: boolean(),
          message: String.t()
        }

  @doc "Runs independent browser-key and server-key checks."
  @spec test_keys(String.t() | nil, String.t() | nil) :: %{
          browser: result(),
          server: result()
        }
  def test_keys(browser_key, server_key) do
    %{
      browser: validate_browser_key(browser_key),
      server: validate_server_key(server_key)
    }
  end

  @doc "Validates a server key against the Places API the application uses."
  @spec validate_server_key(String.t() | nil) :: result()
  def validate_server_key(key) do
    with :ok <- validate_format(key, :server) do
      case request(:post, @places_url,
             json: %{textQuery: "Nairobi, Kenya", maxResultCount: 1},
             headers: [
               {"X-Goog-Api-Key", key},
               {"X-Goog-FieldMask", "places.displayName,places.formattedAddress"}
             ],
             receive_timeout: 8_000,
             retry: false
           ) do
        {:ok, %Req.Response{status: 200}} ->
          ok("Server key is valid for Places API (New) from this server.")

        {:ok, %Req.Response{status: status, body: body}} ->
          server_error(classify(body, status), detail(body))

        {:error, reason} ->
          error("Could not reach Google Places: #{inspect(reason)}")
      end
    else
      {:error, result} -> result
    end
  end

  @doc """
  Validates a browser key against a browser-oriented Google Maps API.

  A fake referrer is sent as well: a correctly restricted key passes the
  KOMIUTA origin and is blocked for the fake origin. If the key is not
  referrer-restricted the check succeeds but returns a warning so the operator
  can lock the key down.
  """
  @spec validate_browser_key(String.t() | nil) :: result()
  def validate_browser_key(key) do
    with :ok <- validate_format(key, :browser) do
      case browser_probe(key, @allowed_referer) do
        {:ok, api} ->
          case browser_probe(key, @blocked_referer) do
            {:ok, _api} ->
              warning(
                "Browser key works, but it accepts an untrusted referrer (#{@blocked_referer}). " <>
                  "Add HTTP referrer restrictions for www.komiuta.com and agent.komiuta.com."
              )

            {:error, :referrer_blocked, _detail} ->
              ok(
                "Browser key is valid and referrer-restricted: #{api} allowed the KOMIUTA origin " <>
                  "and blocked an untrusted referrer."
              )

            {:error, :api_not_enabled, detail} ->
              warning(
                "Browser key allowed the KOMIUTA origin via #{api}, but the blocked-referrer " <>
                  "probe hit an API restriction. Enable Maps Static API or Geocoding API on " <>
                  "the browser key to verify the restriction. #{detail}"
              )

            {:error, kind, detail} ->
              warning(
                "Browser key reached Google but the restriction check could not finish " <>
                  "(#{kind}). #{detail}"
              )
          end

        {:error, :api_not_enabled, detail} ->
          warning(
            "Browser key is saved, but neither Maps Static API nor Geocoding API is enabled " <>
              "for it, so its referrer restriction cannot be tested. #{detail}"
          )

        {:error, kind, detail} ->
          browser_error(kind, detail)
      end
    else
      {:error, result} -> result
    end
  end

  defp browser_probe(key, referer) do
    probes = [{:static_maps, &probe_static_maps/2}, {:geocoding, &probe_geocoding/2}]

    Enum.reduce_while(probes, {:error, :api_not_enabled, "No browser API is enabled."}, fn
      {api, probe}, _last_error ->
        case probe.(key, referer) do
          :ok -> {:halt, {:ok, api}}
          {:error, :api_not_enabled, _detail} = error -> {:cont, error}
          {:error, _kind, _detail} = error -> {:halt, error}
        end
    end)
  end

  defp probe_static_maps(key, referer) do
    case request(:get, @static_map_url,
           params: [center: "Nairobi,Kenya", zoom: 10, size: "64x64", key: key],
           headers: [{"referer", referer}],
           receive_timeout: 8_000,
           retry: false
         ) do
      {:ok, %Req.Response{status: 200, headers: headers}} ->
        if content_type(headers) =~ "image/" do
          :ok
        else
          {:error, :unknown, "Static Maps returned a non-image response."}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        kind = classify(body, status)

        if kind == :api_not_enabled do
          {:error, :api_not_enabled, detail(body)}
        else
          {:error, kind, detail(body)}
        end

      {:error, reason} ->
        {:error, :network, "Static Maps request failed: #{inspect(reason)}"}
    end
  end

  defp probe_geocoding(key, referer) do
    case request(:get, @geocode_url,
           params: [address: "Nairobi, Kenya", key: key],
           headers: [{"referer", referer}],
           receive_timeout: 8_000,
           retry: false
         ) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case body_status(body) do
          "OK" -> :ok
          "ZERO_RESULTS" -> :ok
          status -> {:error, classify(body, 200), body_detail(body, status)}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        kind = classify(body, status)

        if kind == :api_not_enabled do
          {:error, :api_not_enabled, detail(body)}
        else
          {:error, kind, detail(body)}
        end

      {:error, reason} ->
        {:error, :network, "Geocoding request failed: #{inspect(reason)}"}
    end
  end

  defp validate_format(key, label) do
    key = to_string(key || "") |> String.trim()

    cond do
      key == "" ->
        {:error, error("#{label_label(label)} key is missing.")}

      not String.starts_with?(key, "AIza") ->
        {:error, error("#{label_label(label)} key does not look like a Google API key.")}

      true ->
        :ok
    end
  end

  defp label_label(:browser), do: "Browser"
  defp label_label(:server), do: "Server"

  defp server_error(:referrer_blocked, _detail) do
    error(
      "Server key is referrer-restricted. Create a server key with Application " <>
        "restrictions set to None or IP addresses and use it for Places/Geocoding."
    )
  end

  defp server_error(:ip_blocked, detail) do
    error(
      "Server key IP restriction blocks this server. Add the Render service's " <>
        "outbound IPs to the key's allowed IP list. #{detail}"
    )
  end

  defp server_error(:api_not_enabled, detail) do
    error("Places API (New) is not enabled for the server key. #{detail}")
  end

  defp server_error(:invalid_key, detail) do
    error("Server key is invalid. #{detail}")
  end

  defp server_error(:billing, detail) do
    error("Google Maps billing is not enabled for this project. #{detail}")
  end

  defp server_error(kind, detail) do
    error("Places API rejected the server key (#{kind}). #{detail}")
  end

  defp browser_error(:referrer_blocked, detail) do
    error(
      "Browser key does not allow #{@allowed_referer}. Add www.komiuta.com to the " <>
        "key's HTTP referrers. #{detail}"
    )
  end

  defp browser_error(:invalid_key, detail) do
    error("Browser key is invalid. #{detail}")
  end

  defp browser_error(kind, detail) do
    error("Browser key was rejected (#{kind}). #{detail}")
  end

  defp classify(body, status) do
    text = body_text(body) |> String.downcase()

    cond do
      String.contains?(text, "api_key_http_referrer_blocked") or
          (String.contains?(text, "referer") and String.contains?(text, "block")) ->
        :referrer_blocked

      String.contains?(text, "api_key_ip_address_blocked") or
          (String.contains?(text, "ip") and String.contains?(text, "block")) ->
        :ip_blocked

      String.contains?(text, "api_key_service_blocked") or
        String.contains?(text, "service_disabled") or
        String.contains?(text, "not authorized to use this api") or
          String.contains?(text, "api is not enabled") ->
        :api_not_enabled

      String.contains?(text, "api_key_invalid") or String.contains?(text, "invalid api key") ->
        :invalid_key

      String.contains?(text, "billing") ->
        :billing

      status in [401, 403] ->
        :permission_denied

      true ->
        :unknown
    end
  end

  defp body_status(body) when is_map(body), do: Map.get(body, "status")
  defp body_status(_body), do: nil

  defp body_detail(body, status) do
    case is_map(body) && Map.get(body, "error_message") do
      message when is_binary(message) and message != "" -> message
      _ -> "Google responded with #{status || "an error"}."
    end
  end

  defp detail(body) do
    text = body_text(body) |> String.slice(0, 280)
    if text == "", do: "Google returned an empty error response.", else: text
  end

  defp body_text(body) when is_map(body) do
    body
    |> Jason.encode()
    |> case do
      {:ok, text} -> text
      _ -> inspect(body)
    end
  end

  defp body_text(body) when is_binary(body), do: body
  defp body_text(body), do: inspect(body)

  defp content_type(headers) when is_map(headers) do
    Map.get(headers, "content-type", "") |> to_string()
  end

  defp content_type(headers) when is_list(headers) do
    headers
    |> Enum.find_value("", fn {name, value} ->
      if String.downcase(to_string(name)) == "content-type", do: to_string(value)
    end)
    |> to_string()
  end

  defp content_type(_headers), do: ""

  defp request(method, url, opts) do
    case Application.get_env(:xpressbus, :google_maps_http_override) do
      fun when is_function(fun, 3) ->
        fun.(method, url, opts)

      _other ->
        case method do
          :get -> Req.get(url, opts)
          :post -> Req.post(url, opts)
        end
    end
  end

  defp ok(message), do: %{status: :ok, ok: true, message: message}
  defp warning(message), do: %{status: :warning, ok: false, message: message}
  defp error(message), do: %{status: :error, ok: false, message: message}
end
