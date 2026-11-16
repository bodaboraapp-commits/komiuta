defmodule XpressbusWeb.ListingSeoTest do
  use XpressbusWeb.ConnCase

  import Xpressbus.CatalogueFixtures

  alias XpressbusWeb.SEO

  test "hotel, gem, car and event detail pages expose metadata and JSON-LD", %{conn: conn} do
    hotel =
      hotel_fixture(%{name: "SEO Test Hotel", location: "Nairobi", description: "A test hotel."})

    gem =
      hidden_gem_fixture(%{
        title: "SEO Test Gem",
        location: "Naivasha",
        description: "A test gem."
      })

    car = car_hire_fixture(%{car_name: "SEO Test 4x4", location: "Nairobi"})
    event = event_fixture(%{title: "SEO Test Festival", location: "Mombasa"})

    cases = [
      {SEO.listing_path("hotel", hotel), "SEO Test Hotel", "\"@type\":\"Hotel\""},
      {SEO.listing_path("hidden_gem", gem), "SEO Test Gem", "\"@type\":\"TouristAttraction\""},
      {SEO.listing_path("car_hire", car), "SEO Test 4x4", "\"@type\":\"Product\""},
      {SEO.listing_path("event", event), "SEO Test Festival", "\"@type\":\"Event\""}
    ]

    for {path, name, schema_type} <- cases do
      html = conn |> get(path) |> html_response(200)
      assert html =~ name
      assert html =~ "application/ld+json"
      assert html =~ schema_type
      assert html =~ "canonical"
      assert html =~ "<h1"
    end
  end

  test "detail pages link to related listings and back to the index", %{conn: conn} do
    hotel = hotel_fixture(%{name: "Related SEO Hotel", location: "Nairobi", description: "Main."})

    related =
      hotel_fixture(%{name: "Nearby SEO Hotel", location: "Nairobi", description: "Nearby."})

    html =
      conn
      |> get(SEO.listing_path("hotel", hotel))
      |> html_response(200)

    assert html =~ SEO.listing_path("hotel", related)
    assert html =~ "/tour-packages/hotels"
  end

  test "unknown listing slugs return 404", %{conn: conn} do
    assert conn |> get("/tour-packages/hotels/no-such-hotel") |> response(404) ==
             "This listing does not exist or is no longer available."
  end

  test "listing pages add crawlable item links and ItemList JSON-LD", %{conn: conn} do
    hotel = hotel_fixture(%{name: "Crawlable SEO Hotel", location: "Nairobi"})
    html = conn |> get("/tour-packages/hotels") |> html_response(200)

    assert html =~ "Crawlable SEO Hotel"
    assert html =~ "ItemList"
    assert html =~ "hotel-page-#{hotel.id}"
    assert html =~ SEO.listing_path("hotel", hotel)
  end

  test "sitemap includes listing detail pages and images", %{conn: conn} do
    hotel =
      hotel_fixture(%{
        name: "Sitemap SEO Hotel",
        location: "Nairobi",
        images: ["/images/room_1.webp"]
      })

    xml = conn |> get("/sitemap.xml") |> response(200)

    assert xml =~ "xmlns:image"
    assert xml =~ SEO.listing_url("hotel", hotel)
    assert xml =~ "/images/room_1.webp"
  end

  test "AI and feed discovery endpoints are available", %{conn: conn} do
    hotel = hotel_fixture(%{name: "AI Index Hotel", location: "Diani"})

    llms = conn |> get("/llms.txt") |> response(200)
    assert llms =~ "AI Index Hotel"
    assert llms =~ SEO.listing_url("hotel", hotel)

    opensearch = conn |> get("/opensearch.xml") |> response(200)
    assert opensearch =~ "OpenSearchDescription"
    assert opensearch =~ "feeds/listings.xml"

    feed = conn |> get("/feeds/listings.xml") |> response(200)
    assert feed =~ "<feed"
    assert feed =~ "AI Index Hotel"
    assert feed =~ SEO.listing_url("hotel", hotel)
  end
end
