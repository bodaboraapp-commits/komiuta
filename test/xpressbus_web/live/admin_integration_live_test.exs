defmodule XpressbusWeb.AdminIntegrationLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Integrations

  defp admin_conn(conn) do
    Plug.Test.init_test_session(conn, %{admin_id: 1})
  end

  test "admin can select and save the SMS login method", %{conn: conn} do
    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/integration")

    assert html =~ "User Login"

    view |> element("button[phx-value-provider=user_login]") |> render_click()

    assert render(view) =~ "Traveller login method"

    form = element(view, "form[phx-submit=save]")

    form
    |> render_change(%{"config" => %{"method" => "sms"}})

    assert has_element?(view, "input[name='config[method]'][value='sms'][checked]")

    form
    |> render_submit(%{
      "provider" => "user_login",
      "config" => %{"method" => "sms"}
    })

    assert Integrations.login_method() == "sms"
    assert render(view) =~ "Firebase SMS"
  end

  test "defaults to email login", %{conn: conn} do
    {:ok, _view, html} = live(admin_conn(conn), ~p"/admin/integration")

    assert html =~ "User Login"
    assert Integrations.login_method() == "email"
  end
end
