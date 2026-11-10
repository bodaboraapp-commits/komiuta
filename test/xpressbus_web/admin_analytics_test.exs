defmodule XpressbusWeb.AdminAnalyticsTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Analytics

  defp admin_conn(conn) do
    Plug.Test.init_test_session(conn, %{admin_id: "test-admin"})
  end

  test "admin sees the production funnel report", %{conn: conn} do
    {:ok, _} = Analytics.track("signup_started")
    {:ok, _} = Analytics.track("ai_itinerary_generated")
    {:ok, _} = Analytics.track("manage_itinerary_opened")

    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/analytics")

    assert html =~ "Analytics &amp; Funnels"
    assert has_element?(view, "#funnel-signup")
    assert has_element?(view, "#funnel-ai")
    assert has_element?(view, "#funnel-manage")
    assert has_element?(view, "#funnel-signup", "Opened signup")

    view |> element("#analytics-period-7") |> render_click()
    assert render(view) =~ "Last 7 days"
  end
end
