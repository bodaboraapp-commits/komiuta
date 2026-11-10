defmodule XpressbusWeb.AdminIntegrationMapsTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.GooglePlaces
  alias Xpressbus.Integrations
  alias Xpressbus.Integrations.PaymentConfig
  alias Xpressbus.Repo

  import Ecto.Query

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  defp mock_response(status, body, content_type \\ "application/json") do
    {:ok, %Req.Response{status: status, headers: %{"content-type" => content_type}, body: body}}
  end

  test "saves separate browser and server Google Maps keys", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/integration")

    view |> element("button", "Google Maps") |> render_click()

    assert has_element?(view, "#google-maps-form")
    assert has_element?(view, "#google-maps-form input[name='config[browser_key]']")
    assert has_element?(view, "#google-maps-form input[name='config[server_key]']")

    view
    |> form("#google-maps-form", %{
      "provider" => "google_maps",
      "config" => %{
        "browser_key" => "AIzaBrowserKey123",
        "server_key" => "AIzaServerKey123"
      }
    })
    |> render_submit()

    assert render(view) =~ "Google Maps settings saved successfully"

    saved = Integrations.get_config_by_provider("google_maps")
    assert saved.config["browser_key"] == "AIzaBrowserKey123"
    assert saved.config["server_key"] == "AIzaServerKey123"
    assert Integrations.google_maps_browser_key() == "AIzaBrowserKey123"
    assert Integrations.google_maps_server_key() == "AIzaServerKey123"
    assert Integrations.google_maps_configured?()
  end

  test "legacy api_key is a server-key fallback, never a browser key" do
    Repo.delete_all(from(config in PaymentConfig, where: config.provider == "google_maps"))

    {:ok, _config} =
      Integrations.upsert_config_by_provider("google_maps", %{
        active: true,
        config: %{"api_key" => "AIzaLegacyKey123"}
      })

    assert Integrations.google_maps_browser_key() == nil
    assert Integrations.google_maps_server_key() == "AIzaLegacyKey123"
    refute Integrations.google_maps_configured?()
  end

  test "Test API runs real browser and server restriction checks", %{conn: conn} do
    previous_http = Application.get_env(:xpressbus, :google_maps_http_override)

    Application.put_env(:xpressbus, :google_maps_http_override, fn
      :post, _url, _opts -> mock_response(200, %{"places" => []})
      :get, _url, _opts -> mock_response(200, "", "image/png")
    end)

    on_exit(fn ->
      if previous_http do
        Application.put_env(:xpressbus, :google_maps_http_override, previous_http)
      else
        Application.delete_env(:xpressbus, :google_maps_http_override)
      end
    end)

    {:ok, _config} =
      Integrations.upsert_config_by_provider("google_maps", %{
        active: true,
        config: %{
          "browser_key" => "AIzaBrowserKey123",
          "server_key" => "AIzaServerKey123"
        }
      })

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/integration")
    view |> element("button", "Google Maps") |> render_click()

    html = view |> element("button", "Test API") |> render_click()

    assert html =~ "Browser key — Warning"
    assert html =~ "Server key — OK"
    assert html =~ "accepts an untrusted referrer"
  end

  test "server-side Static Maps uses the server key, not the browser key" do
    Repo.delete_all(from(config in PaymentConfig, where: config.provider == "google_maps"))

    {:ok, _config} =
      Integrations.upsert_config_by_provider("google_maps", %{
        active: true,
        config: %{
          "browser_key" => "AIzaBrowserKey123",
          "server_key" => "AIzaServerKey123"
        }
      })

    previous = Application.get_env(:xpressbus, :google_places_enabled)
    Application.put_env(:xpressbus, :google_places_enabled, true)
    on_exit(fn -> Application.put_env(:xpressbus, :google_places_enabled, previous) end)

    url = GooglePlaces.static_map("Moscow")

    assert url =~ "AIzaServerKey123"
    refute url =~ "AIzaBrowserKey123"
  end
end
