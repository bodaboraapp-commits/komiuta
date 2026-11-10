defmodule XpressbusWeb.AdminIntegrationWeatherTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Integrations
  alias Xpressbus.Weather

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  test "WeatherAPI lives under System Integrations and saves the key", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/integration")

    # WeatherAPI is a tab on the existing Settings → Integrations page.
    view |> element("button", "WeatherAPI") |> render_click()

    assert has_element?(view, "#weather-api-form")
    assert has_element?(view, "#weather-api-form input[name='config[api_key]']")

    view
    |> form("#weather-api-form", %{
      "provider" => "weather_api",
      "config" => %{"api_key" => "wa-test-key-123"}
    })
    |> render_submit()

    assert render(view) =~ "WeatherAPI settings saved successfully"

    saved = Integrations.get_config_by_provider("weather_api")
    assert saved.config["api_key"] == "wa-test-key-123"
    assert saved.active

    assert Weather.provider() == :weatherapi
    assert Weather.weatherapi_config() == %{api_key: "wa-test-key-123"}
  end

  test "disabling the WeatherAPI integration returns Chyllz to Open-Meteo", %{conn: conn} do
    {:ok, _config} =
      Integrations.upsert_config_by_provider("weather_api", %{
        active: true,
        config: %{"api_key" => "wa-test-key-123"}
      })

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/integration")
    view |> element("button", "WeatherAPI") |> render_click()

    view
    |> element("#weather-api-form input[phx-value-provider='weather_api']")
    |> render_click()

    refute Integrations.get_config_by_provider("weather_api").active
    assert Weather.provider() == :open_meteo
  end
end
