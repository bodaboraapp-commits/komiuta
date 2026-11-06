defmodule Xpressbus.Bookings.DepartureWindowTest do
  @moduledoc """
  Search results must never show a bus that departs less than two hours from
  now (Kenya time) — or one that has already left.
  """

  use ExUnit.Case, async: true

  alias Xpressbus.Bookings.DepartureWindow

  @date ~D[2026-11-06]
  @now ~N[2026-11-06 09:00:00]

  defp buses(times) do
    Enum.map(times, fn departure ->
      %{departure: departure, company: "Coach", price: "KSH 1,000"}
    end)
  end

  defp kept_times(times, date \\ @date) do
    times
    |> buses()
    |> DepartureWindow.filter_bookable(date, now: @now)
    |> Enum.map(& &1.departure)
  end

  test "hides departures within the next two hours and departures that already left" do
    assert kept_times([
             "7:30 AM",
             "8:59 AM",
             "9:00 AM",
             "10:00 AM",
             "10:59 AM",
             "11:00 AM",
             "11:30 AM",
             "12:00 PM",
             "7:00 PM"
           ]) == ["11:00 AM", "11:30 AM", "12:00 PM", "7:00 PM"]
  end

  test "supports 24 hour departure strings" do
    assert kept_times(["08:00", "10:59", "11:00", "17:30"]) == ["11:00", "17:30"]
  end

  test "supports compact AM/PM and hour-only departure strings" do
    assert kept_times(["7:00AM", "10:30am", "11:15am", "7 PM"]) == ["11:15am", "7 PM"]
  end

  test "hides buses whose departure time cannot be parsed" do
    assert kept_times(["", "   ", "Soon", "Direct", nil]) == []
  end

  test "does not affect future travel dates" do
    assert kept_times(["6:00 AM", "9:00 AM"], ~D[2026-11-07]) == ["6:00 AM", "9:00 AM"]
  end

  test "returns buses unchanged when the travel date is invalid" do
    buses = buses(["6:00 AM"])

    assert DepartureWindow.filter_bookable(buses, "not-a-date", now: @now) == buses
  end

  test "parses departure formats into times" do
    assert DepartureWindow.parse_departure_time("7:00 AM") == {:ok, ~T[07:00:00]}
    assert DepartureWindow.parse_departure_time("7:00pm") == {:ok, ~T[19:00:00]}
    assert DepartureWindow.parse_departure_time("07:30") == {:ok, ~T[07:30:00]}
    assert DepartureWindow.parse_departure_time("12:00 AM") == {:ok, ~T[00:00:00]}
    assert DepartureWindow.parse_departure_time("12:30 PM") == {:ok, ~T[12:30:00]}
    assert DepartureWindow.parse_departure_time("7 PM") == {:ok, ~T[19:00:00]}
    assert DepartureWindow.parse_departure_time("25:00") == :error
    assert DepartureWindow.parse_departure_time("13:00 PM") == :error
    assert DepartureWindow.parse_departure_time(nil) == :error
  end

  test "keeps the rest of the bus payload intact" do
    [bus] = DepartureWindow.filter_bookable(buses(["2:00 PM"]), @date, now: @now)

    assert bus.company == "Coach"
    assert bus.price == "KSH 1,000"
  end

  test "exposes the two hour lead time" do
    assert DepartureWindow.min_lead_time_hours() == 2
  end
end
