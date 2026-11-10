defmodule XpressbusWeb.DeviceCompatibilityTest do
  use XpressbusWeb.ConnCase

  test "serves a real mobile viewport instead of a release marker", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover")
    refute html =~ ~r/<meta name="viewport" content="20\d{2}-/
  end
end
