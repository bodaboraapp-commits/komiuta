defmodule XpressbusWeb.DashboardBookingsTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures
  import Xpressbus.CatalogueFixtures

  alias Xpressbus.HotelBookings
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  defp signed_in(conn, user), do: Plug.Test.init_test_session(conn, %{user_id: user.id})

  defp ticket_fixture(attrs) do
    defaults = %{
      ticket_id: "TKT-#{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Mombasa",
      travel_date: Date.utc_today(),
      departure: "7:00 AM",
      arrival: "1:30 PM",
      company: "MashPoa",
      price: "2300",
      seats: "[\"6\"]",
      passenger_name: "Someone Else",
      passenger_phone: "0700000000",
      payment_method: "mpesa",
      status: "confirmed",
      type: "One Way"
    }

    Repo.insert!(struct(Ticket, Map.merge(defaults, attrs)))
  end

  test "My Bus shows bookings paid for by the signed-in user", %{conn: conn} do
    user = user_fixture()
    ticket = ticket_fixture(%{})

    pay_reference = "ws_CO_test_#{System.unique_integer([:positive])}"

    Repo.insert!(%Payment{
      provider: "mpesa",
      amount: 2300,
      reference: pay_reference,
      ticket_id: ticket.ticket_id,
      status: "success",
      raw_response: %{
        "booking_context" => %{"user_id" => user.id, "ticket_id" => ticket.ticket_id}
      }
    })

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard")

    assert has_element?(view, "#ticket-card-#{ticket.ticket_id}")
  end

  test "My Chyllz lists all accommodation bookings for the account", %{conn: conn} do
    user = user_fixture()
    hotel = hotel_fixture(%{name: "Diani Beach House", location: "Diani"})
    check_in = Date.add(Date.utc_today(), 2)

    assert {:ok, booking} =
             HotelBookings.create_booking(user, hotel, %{
               "check_in" => Date.to_iso8601(check_in),
               "check_out" => Date.to_iso8601(Date.add(check_in, 2)),
               "rooms" => "1",
               "guests" => "2"
             })

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert has_element?(view, "#hotel-bookings")
    assert has_element?(view, "#hotel-booking-#{booking.reference}")
    assert has_element?(view, "#hotel-booking-#{booking.reference}", "Diani Beach House")
    assert has_element?(view, "#hotel-booking-#{booking.reference}", "KES 25,000")
    refute has_element?(view, "#no-hotel-bookings")
  end
end
