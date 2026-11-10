defmodule Xpressbus.Bookings.SearchTest do
  @moduledoc """
  Database search returns only bookable buses: hygienic rows (no legacy
  fallback, no sold-out) that also pass the two hour departure window.
  """

  use Xpressbus.DataCase, async: false

  alias Xpressbus.Bookings.{Bus, Search}
  alias Xpressbus.Repo

  @date ~D[2026-11-06]
  @now ~N[2026-11-06 09:00:00]

  defp bus_fixture(attrs) do
    attrs =
      Map.merge(
        %{
          company: "Search Test #{System.unique_integer([:positive])}",
          departure: "2:00 PM",
          arrival: "6:00 PM",
          seats: "20 seats left",
          price: "KES 1,500",
          registration: "SRC #{System.unique_integer([:positive])}",
          from: "Nairobi",
          to: "Mombasa",
          travel_date: @date,
          duration: "4h 30m",
          occupied_seats: [],
          total_seats: 40
        },
        attrs
      )

    %Bus{} |> Bus.changeset(attrs) |> Repo.insert!()
  end

  test "only returns buses outside the two hour departure window" do
    bus_fixture(%{departure: "7:00 AM"})
    bus_fixture(%{departure: "10:30 AM"})
    bus_fixture(%{departure: "11:00 AM"})
    bus_fixture(%{departure: "2:00 PM"})

    departures =
      "Nairobi"
      |> Search.list_bookable("Mombasa", @date, now: @now)
      |> Enum.map(& &1.departure)

    assert departures == ["11:00 AM", "2:00 PM"]
  end

  test "keeps the existing hygiene filters" do
    bus_fixture(%{departure: "1:00 PM", seats: "0 seats left"})
    bus_fixture(%{departure: "1:30 PM", source: "legacy_fallback"})
    bus_fixture(%{departure: "2:30 PM"})

    departures =
      Search.list_bookable("Nairobi", "Mombasa", @date, now: @now)
      |> Enum.map(& &1.departure)

    assert departures == ["2:30 PM"]
  end

  test "does not apply the window to future travel dates" do
    bus_fixture(%{departure: "6:00 AM", travel_date: ~D[2026-11-07], company: "Tomorrow Coach"})

    departures =
      Search.list_bookable("Nairobi", "Mombasa", ~D[2026-11-07], now: @now)
      |> Enum.map(& &1.departure)

    assert departures == ["6:00 AM"]
  end

  test "returns an empty list for an invalid date" do
    assert Search.list_bookable("Nairobi", "Mombasa", "not-a-date", now: @now) == []
  end

  test "only returns the requested route" do
    bus_fixture(%{departure: "2:00 PM"})
    bus_fixture(%{departure: "2:00 PM", to: "Kisumu"})

    buses = Search.list_bookable("Nairobi", "Mombasa", @date, now: @now)

    assert Enum.all?(buses, &(&1.to == "Mombasa"))
  end
end
