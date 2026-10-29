defmodule XpressbusWeb.ErrorHTMLTest do
  use XpressbusWeb.ConnCase, async: true

  defp error_page(template) do
    {:safe, html} = XpressbusWeb.ErrorHTML.render(template, %{})
    IO.iodata_to_binary(html)
  end

  describe "error pages" do
    test "renders the branded 404 page" do
      html = error_page("404.html")

      assert html =~ "Error 404"
      assert html =~ "This page took a different route"
      assert html =~ "Track my ticket"
    end

    test "renders the branded 500 page" do
      html = error_page("500.html")

      assert html =~ "Error 500"
      assert html =~ "We hit a temporary snag"
      assert html =~ "hello@komiuta.com"
    end

    test "falls back to the status message for other codes" do
      assert XpressbusWeb.ErrorHTML.render("403.html", %{}) == "Forbidden"
    end
  end
end
