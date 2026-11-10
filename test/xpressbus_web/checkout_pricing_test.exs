defmodule XpressbusWeb.CheckoutPricingTest do
  @moduledoc """
  Checkout must use one price source: the search card's fare, the seat map's
  per-seat price and the final payable amount (base fare + KES 50 convenience
  fee) must agree.
  """

  use XpressbusWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Repo

  defp bus_fixture(attrs) do
    travel_date = Date.add(Date.utc_today(), 1)

    defaults = %{
      company: "Pricing Coach",
      departure: "10:00 AM",
      arrival: "2:00 PM",
      seats: "20 seats left",
      price: "KES 2,000",
      registration: "PRC #{System.unique_integer([:positive])}",
      from: "nairobi",
      to: "mombasa",
      travel_date: travel_date,
      duration: "4h 0m",
      occupied_seats: [],
      total_seats: 40,
      seat_types: ["Normal"],
      source: "buupass_api"
    }

    %Bus{}
    |> Bus.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  test "normal-only bus: seat map prices every seat at the fare shown on the card", %{
    conn: conn
  } do
    bus = bus_fixture(%{})
    travel_date = bus.travel_date

    {:ok, view, _html} =
      live(
        conn,
        "/buses/nairobi-to-mombasa?fromCityName=nairobi&toCityName=mombasa&onward=#{travel_date}"
      )

    view
    |> element("button[phx-click='select_bus'][phx-value-id='#{bus.id}']")
    |> render_click()

    html = render(view)

    # Every seat is Normal when the operator only sells Normal; no phantom
    # First/VIP/Business seats at invented prices.
    assert html =~ "Normal Seat 1"
    refute html =~ "First Class Seat 1"
    refute html =~ "Vip Seat 1"

    view
    |> element("button[phx-value-seat='1']")
    |> render_click()

    # Seat drawer shows the base fare; the KES 50 fee is added at checkout.
    assert render(view) =~ "TOTAL FARE"
    assert render(view) =~ "KES 2000"
  end

  test "checkout template shows the convenience fee and wires the payable total" do
    template = File.read!("lib/xpressbus_web/live/booking_live.html.heex")

    assert template =~ "CONVENIENCE FEE"
    assert template =~ "@convenience_fee"
    assert template =~ "@tax_amount"
    assert template =~ "PAY KES {@final_price}"
    refute template =~ "TAXES & FEES"
  end
end
