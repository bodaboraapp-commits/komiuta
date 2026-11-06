defmodule Xpressbus.Bookings.ScraperTest do
  use Xpressbus.DataCase, async: false

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Bookings.{Scraper, Search}
  alias Xpressbus.BusOperators.BusOperator
  alias Xpressbus.Repo

  # A future travel date so the 2-hour departure window never removes fixtures.
  @search_date ~D[2026-11-20]

  @sse """
  data: {"provider": "chania", "data": [{"from": "Nairobi", "to": "Ukunda", "departure_date": "2026-11-06", "operator": {"alias": "chania", "name": "Chania Executive Special", "logo": "https://example.com/chania.webp"}, "trip_id": 5, "departure_time": "21:00:00", "arrival_time": "06:00:00", "number_of_available_seats": 38, "fare": 0.0, "bus_capacity": 47, "seats_types": [{"alias": "normal", "fare": 2000, "name": "Normal", "currency": "KSH"}]}], "status": false, "completed": false}
  data: {"data": {}, "status": true, "completed": true}
  """

  test "parse_stream maps a real BuuPass SSE payload to a Bus" do
    assert [bus] = Scraper.parse_stream(@sse, "Nairobi", "Ukunda", ~D[2026-11-06])

    assert bus.company == "Chania Executive Special"
    assert bus.departure == "9:00 PM"
    assert bus.arrival == "6:00 AM"
    assert bus.price == "KSH 2000"
    assert bus.duration == "9h 0m"
    assert bus.seats == "38 seats left"
    assert bus.source == "buupass_api"
    assert bus.first_class_price == ""
    assert bus.logo_url == "https://example.com/chania.webp"
  end

  test "public search ignores legacy fallback buses" do
    legacy = bus_fixture(%{company: "Fake Coach", source: "legacy_fallback"})
    real = bus_fixture(%{company: "Real Coach", source: "buupass_api"})

    buses = Scraper.search("Nairobi", "Ukunda", @search_date)

    ids = Enum.map(buses, & &1.id)
    assert real.id in ids
    refute legacy.id in ids
  end

  test "the scraper cache and the database search return the same public buses" do
    approved = bus_operator_fixture("Approved Coach", true)
    unapproved = bus_operator_fixture("Unapproved Coach", false)

    visible = bus_fixture(%{company: "Approved Coach", bus_operator_id: approved.id})
    hidden = bus_fixture(%{company: "Unapproved Coach", bus_operator_id: unapproved.id})
    bus_fixture(%{company: "Sold Out Coach", seats: "0 seats left"})

    search_ids =
      "Nairobi"
      |> Search.list_bookable("Ukunda", @search_date)
      |> Enum.map(& &1.id)
      |> Enum.sort()

    scraper_ids =
      "Nairobi"
      |> Scraper.search("Ukunda", @search_date)
      |> Enum.map(& &1.id)
      |> Enum.sort()

    assert visible.id in search_ids
    refute hidden.id in search_ids
    assert search_ids == scraper_ids
  end

  test "seat_type_available? reflects the classes the operator actually offers" do
    bus = %{seat_types: ["Normal"]}

    refute XpressbusWeb.BookingLive.seat_type_available?(bus, ["vip"])
    refute XpressbusWeb.BookingLive.seat_type_available?(bus, ["first", "first class"])
    assert XpressbusWeb.BookingLive.seat_type_available?(bus, ["normal"])
  end

  test "parse_stream handles a direct shuttle with no arrival time and hides sold-out buses" do
    direct = """
    data: {"provider": "greenline_new", "data": [{"operator": {"name": "Greenline"}, "departure_time": "21:00:00", "arrival_time": "", "number_of_available_seats": 67, "fare": 1500, "seats_types": [{"alias": "business", "fare": 1500, "name": "Normal", "currency": "KES"}], "trip_id": 128}, {"operator": {"name": "Sold Out"}, "departure_time": "22:00:00", "arrival_time": "", "number_of_available_seats": 0, "fare": 1500, "seats_types": [], "trip_id": 9}], "status": false, "completed": false}
    """

    assert [bus] = Scraper.parse_stream(direct, "Nairobi", "Kisumu", ~D[2026-11-06])
    assert bus.company == "Greenline"
    assert bus.arrival == "Direct"
    assert bus.duration == "Direct"
    assert bus.price == "KES 1500"
  end

  test "parse_stream maps Mozaico business/first_class/vip fares" do
    payload = """
    data: {"provider": "mozaico", "data": [{"operator": {"name": "Mozaico"}, "departure_time": "16:00:00", "arrival_time": "00:00:00", "number_of_available_seats": 16, "fare": 0, "bus_capacity": 44, "seats_types": [{"alias": "business", "fare": 2500, "name": "Business", "currency": "KES"}, {"alias": "first_class", "fare": 2700, "name": "First Class", "currency": "KES"}, {"alias": "vip", "fare": 3500, "name": "VIP", "currency": "KES"}], "trip_id": 77}], "status": false, "completed": false}
    """

    assert [bus] = Scraper.parse_stream(payload, "Nairobi", "Kisumu", ~D[2026-11-06])
    assert bus.price == "KES 2500"
    assert bus.business_price == "KES 2500"
    assert bus.first_class_price == "KES 2700"
    assert bus.vip_price == "KES 3500"
  end

  test "filter_soon_departures hides same-day trips inside the two-hour window" do
    now_utc = ~U[2026-11-06 07:00:00Z]

    buses = [
      %{travel_date: ~D[2026-11-06], departure: "11:00 AM"},
      %{travel_date: ~D[2026-11-06], departure: "12:00 PM"},
      %{travel_date: ~D[2026-11-07], departure: "8:00 AM"}
    ]

    assert [%{departure: "12:00 PM"}, %{departure: "8:00 AM"}] =
             Scraper.filter_soon_departures(buses, now_utc)
  end

  defp bus_operator_fixture(name, active) do
    Repo.insert!(%BusOperator{
      name: "#{name} #{System.unique_integer([:positive])}",
      active: active
    })
  end

  defp bus_fixture(attrs) do
    defaults = %{
      company: "Test Coach",
      departure: "10:00 AM",
      arrival: "2:00 PM",
      seats: "20 seats left",
      price: "KSH 1,500",
      registration: "TEST #{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Ukunda",
      travel_date: @search_date,
      duration: "4h 0m",
      occupied_seats: [],
      total_seats: 40
    }

    %Bus{}
    |> Bus.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
