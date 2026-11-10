defmodule XpressbusWeb.SearchCardRenderTest do
  @moduledoc """
  Renders a real search-results bus card and asserts the journey timeline no
  longer lets the bus icon overlap the duration/time label.
  """

  use XpressbusWeb.ConnCase

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Repo

  # Search results hide buses departing less than 2 hours from now (EAT), so
  # fixture a departure comfortably outside that window on today's EAT date.
  defp future_times(hours_ahead) do
    now_eat =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(3 * 3_600, :second)
      |> NaiveDateTime.truncate(:second)

    departure = NaiveDateTime.add(now_eat, hours_ahead * 3_600, :second)
    arrival = NaiveDateTime.add(departure, 4 * 3_600, :second)

    {departure, arrival}
  end

  defp format_time(%NaiveDateTime{hour: hour, minute: minute}) do
    suffix = if hour < 12, do: "AM", else: "PM"
    hour = hour |> rem(12) |> then(&if(&1 == 0, do: 12, else: &1))
    "#{hour}:#{String.pad_leading(to_string(minute), 2, "0")} #{suffix}"
  end

  defp bus_fixture do
    {departure, arrival} = future_times(4)
    travel_date = NaiveDateTime.to_date(NaiveDateTime.add(departure, -4 * 3_600, :second))

    {:ok, bus} =
      %Bus{}
      |> Bus.changeset(%{
        company: "Test Coaches",
        departure: format_time(departure),
        arrival: format_time(arrival),
        seats: "28 seats left",
        price: "KES 1,500",
        registration: "KAA 123B",
        from: "nairobi",
        to: "mombasa",
        travel_date: travel_date,
        duration: "4h 30m",
        occupied_seats: [],
        total_seats: 40
      })
      |> Repo.insert()

    {bus, format_time(departure), format_time(arrival), travel_date}
  end

  test "results card timeline keeps the label clear of the bus icon", %{conn: conn} do
    {_bus, departure, arrival, travel_date} = bus_fixture()

    html =
      conn
      |> get(
        "/buses/nairobi-to-mombasa?fromCityName=nairobi&toCityName=mombasa&onward=#{travel_date}"
      )
      |> html_response(200)

    assert html =~ departure
    assert html =~ arrival
    assert html =~ "4h 30m"
    assert html =~ "28 seats left"

    # Icon is rendered in the inline white chip, not absolutely positioned over
    # the label above the line.
    assert html =~ "directions_bus"
    refute html =~ "-top-3.5"
    refute html =~ "absolute inset-0 flex items-center justify-center -top"
  end
end
