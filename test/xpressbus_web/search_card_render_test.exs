defmodule XpressbusWeb.SearchCardRenderTest do
  @moduledoc """
  Renders a real search-results bus card and asserts the journey timeline no
  longer lets the bus icon overlap the duration/time label.
  """

  use XpressbusWeb.ConnCase

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Repo

  defp bus_fixture do
    {:ok, bus} =
      %Bus{}
      |> Bus.changeset(%{
        company: "Test Coaches",
        departure: "10:00 AM",
        arrival: "2:00 PM",
        seats: "28 seats left",
        price: "KSH 1,500",
        registration: "KAA 123B",
        from: "nairobi",
        to: "mombasa",
        travel_date: Date.utc_today(),
        duration: "4h 30m",
        occupied_seats: [],
        total_seats: 40
      })
      |> Repo.insert()

    bus
  end

  test "results card timeline keeps the label clear of the bus icon", %{conn: conn} do
    _bus = bus_fixture()

    html = conn |> get(~p"/buses/nairobi-to-mombasa") |> html_response(200)

    assert html =~ "10:00 AM"
    assert html =~ "2:00 PM"
    assert html =~ "4h 30m"
    assert html =~ "28 seats left"

    # Icon is rendered in the inline white chip, not absolutely positioned over
    # the label above the line.
    assert html =~ "directions_bus"
    refute html =~ "-top-3.5"
    refute html =~ "absolute inset-0 flex items-center justify-center -top"
  end
end
