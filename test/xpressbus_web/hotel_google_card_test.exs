defmodule XpressbusWeb.HotelGoogleCardTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.CatalogueFixtures

  test "hotel cards render the Google photo path and review count", %{conn: conn} do
    hotel =
      hotel_fixture(%{
        name: "Sarova Stanley",
        location: "Nairobi",
        review_count: 3_456,
        images: ["/places/photo?ref=places%2Fplace-1%2Fphotos%2Fphoto-2"]
      })

    {:ok, view, _html} = live(conn, ~p"/tour-packages/hotels")

    html = render(view)
    assert has_element?(view, "#hotel-card-#{hotel.id}")
    assert html =~ "/places/photo?ref="
    assert html =~ "3456"
  end
end
