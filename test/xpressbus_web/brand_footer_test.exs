defmodule XpressbusWeb.BrandFooterTest do
  @moduledoc """
  The public footer must expose the website, support contacts and social links;
  these are centralised in `Xpressbus.Brand` and shared with transactional email.
  """

  use XpressbusWeb.ConnCase

  test "footer shows website, contact details and social links", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ "www.komiuta.com"
    assert html =~ "hello@komiuta.com"
    assert html =~ "0800 211 211"

    for %{name: name, url: url} <- Xpressbus.Brand.social_links() do
      assert html =~ name
      assert html =~ url
    end

    # Social links open safely in a new tab.
    assert html =~ ~s(rel="noopener noreferrer")
  end

  test "brand contact details are consistent" do
    assert Xpressbus.Brand.website() == "https://www.komiuta.com"
    assert Xpressbus.Brand.website_label() == "www.komiuta.com"
    assert Xpressbus.Brand.email() == "hello@komiuta.com"
    assert Xpressbus.Brand.phone() == "0800 211 211"
    assert Xpressbus.Brand.phone_uri() == "tel:0800211211"
    assert length(Xpressbus.Brand.social_links()) >= 4
  end
end
