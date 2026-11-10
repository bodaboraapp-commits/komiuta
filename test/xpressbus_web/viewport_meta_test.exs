defmodule XpressbusWeb.ViewportMetaTest do
  use XpressbusWeb.ConnCase

  test "the root layout keeps a real responsive viewport", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~s(name="viewport" content="width=device-width, initial-scale=1)
    assert html =~ ~s(name="app-release")
    refute html =~ ~r/name="viewport" content="20\d\d-/
  end
end
