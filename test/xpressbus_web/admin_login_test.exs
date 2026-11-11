defmodule XpressbusWeb.AdminLoginTest do
  use XpressbusWeb.ConnCase

  test "admin login has a descriptive document title", %{conn: conn} do
    conn = get(conn, ~p"/admin/login")
    html = html_response(conn, 200)

    assert html =~ ">Admin Login | KOMIUTA</title>"
  end
end
