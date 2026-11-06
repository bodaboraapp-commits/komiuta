defmodule Xpressbus.Bookings.ScraperTest do
  use Xpressbus.DataCase, async: false

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Bookings.Scraper
  alias Xpressbus.Repo

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

    buses = Scraper.search("Nairobi", "Ukunda", "2026-11-06")

    ids = Enum.map(buses, & &1.id)
    assert real.id in ids
    refute legacy.id in ids
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

  defp bus_fixture(attrs) do
    defaults = %{
      company: "Test Coach",
      departure: "10:00 AM",
      arrival: "2:00 PM",
      seats: "20 seats left",
      price: "KSH 1,500",
      registration: "TEST 001A",
      from: "Nairobi",
      to: "Ukunda",
      travel_date: ~D[2026-11-06],
      duration: "4h 0m",
      occupied_seats: [],
      total_seats: 40
    }

    %Bus{}
    |> Bus.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
