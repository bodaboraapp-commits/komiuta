defmodule XpressbusWeb.DeviceCompatibilityTest do
  use XpressbusWeb.ConnCase

  test "serves a real mobile viewport instead of a release marker", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(content="width=device-width, initial-scale=1, viewport-fit=cover")
    refute html =~ "content=\"2026-11-10.38-stays-before-itineraries\""
  end
end
