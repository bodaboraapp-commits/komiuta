defmodule XpressbusWeb.SeoTest do
  @moduledoc """
  Guards the search/AI-search surface: sitemap, robots, llms.txt, canonical
  metadata, route landing schema and utility-page noindex.
  """
  use XpressbusWeb.ConnCase, async: true

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Repo

  defp route_bus_fixture do
    {:ok, bus} =
      %Bus{}
      |> Bus.changeset(%{
        company: "SEO Coaches",
        departure: "10:00 AM",
        arrival: "2:00 PM",
        seats: "28 seats left",
        price: "KSH 1,500",
        registration: "SEO 001A",
        from: "SeoCity",
        to: "SeoTown",
        travel_date: Date.utc_today(),
        duration: "4h 30m",
        occupied_seats: [],
        total_seats: 40
      })
      |> Repo.insert()

    bus
  end

  test "sitemap exposes static pages and route landing URLs", %{conn: conn} do
    _bus = route_bus_fixture()

    conn = get(conn, "/sitemap.xml")

    body = response(conn, 200)
    assert body =~ "<urlset"
    assert body =~ "https://www.komiuta.com/"
    assert body =~ "/tour-packages/insurance"
    assert body =~ "/buses/SeoCity-to-SeoTown"
    assert get_resp_header(conn, "content-type") |> hd() =~ "xml"
  end

  test "robots.txt allows search/AI crawlers and points at the sitemap", %{conn: conn} do
    body = get(conn, "/robots.txt").resp_body

    assert body =~ "Sitemap: https://www.komiuta.com/sitemap.xml"
    assert body =~ "User-agent: GPTBot"
    assert body =~ "User-agent: PerplexityBot"
    assert body =~ "Disallow: /admin"
  end

  test "llms.txt describes Komiuta and key route pages", %{conn: conn} do
    body = get(conn, "/llms.txt").resp_body

    assert body =~ "Komiuta"
    assert body =~ "/buses/Nairobi-to-Kisumu"
    assert body =~ "M-PESA"
  end

  test "homepage has canonical metadata and Organization/WebSite schema", %{conn: conn} do
    body = get(conn, "/").resp_body

    assert body =~ "Bus Tickets, Chyllz &amp; Travel | Komiuta"
    assert body =~ "rel=\"canonical\""
    assert body =~ "application/ld+json"
    assert body =~ "\"@type\":\"Organization\""
    assert body =~ "\"@type\":\"WebSite\""
    assert body =~ "Kenya's most-booked bus routes"
  end

  test "route landing page has route title, canonical, BusTrip and FAQ schema", %{conn: conn} do
    body = get(conn, "/buses/Nairobi-to-Kisumu").resp_body

    assert body =~ "Nairobi to Kisumu Bus Tickets"
    assert body =~ "rel=\"canonical\" href=\"https://www.komiuta.com/buses/Nairobi-to-Kisumu\""
    assert body =~ "\"@type\":\"BusTrip\""
    assert body =~ "\"@type\":\"FAQPage\""
    assert body =~ "Frequently asked questions"
    assert body =~ "Nairobi to Kisumu bus tickets — fares, schedule &amp; booking"
  end

  test "utility ticket page is noindex", %{conn: conn} do
    body = get(conn, "/tickets").resp_body

    assert body =~ "name=\"robots\" content=\"noindex,follow\""
  end
end
