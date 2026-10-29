defmodule XpressbusWeb.PageControllerTest do
  use XpressbusWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Online Bus Ticket Booking"
  end
end
