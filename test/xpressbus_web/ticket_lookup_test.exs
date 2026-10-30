defmodule XpressbusWeb.TicketLookupTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  defp ticket_fixture(attrs \\ %{}) do
    defaults = %{
      ticket_id: "TKT-#{System.unique_integer([:positive])}",
      from: "Mombasa",
      to: "Nairobi",
      travel_date: ~D[2026-11-01],
      departure: "7:00 AM",
      arrival: "5:30 PM",
      company: "MashPoa",
      price: "KSH 2300",
      seats: "[\"6\"]",
      passenger_name: "Private Passenger",
      passenger_phone: "0712345678",
      payment_method: "mpesa",
      status: "confirmed",
      type: "One Way"
    }

    Repo.insert!(struct(Ticket, Map.merge(defaults, attrs)))
  end

  test "unauthenticated lookup requires the phone last 4 digits", %{conn: conn} do
    ticket = ticket_fixture()

    {:ok, view, _html} = live(conn, ~p"/tickets")

    # Ticket ID alone must not reveal the booking.
    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "last4" => ""})
      |> render_submit()

    refute html =~ "Private Passenger"
    assert html =~ "No ticket matches"

    # Wrong digits also reveal nothing.
    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "last4" => "0000"})
      |> render_submit()

    refute html =~ "Private Passenger"

    # Correct digits reveal the ticket.
    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "last4" => "5678"})
      |> render_submit()

    assert html =~ "Private Passenger"
    assert html =~ ticket.ticket_id
  end

  test "a signed-in passenger can view their own ticket without re-entering digits", %{conn: conn} do
    user = user_fixture(%{phone: "0712345678"})
    ticket = ticket_fixture(%{passenger_name: user.name, passenger_phone: user.phone})

    conn = Plug.Test.init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/tickets")

    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "last4" => ""})
      |> render_submit()

    assert html =~ user.name
    assert html =~ ticket.ticket_id
  end
end
