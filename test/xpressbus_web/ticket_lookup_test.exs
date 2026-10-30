defmodule XpressbusWeb.TicketLookupTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.Repo
  alias Xpressbus.TicketAccess
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

  test "unauthenticated lookup requires the ticket ID and full passenger phone", %{conn: conn} do
    ticket = ticket_fixture()

    {:ok, view, _html} = live(conn, ~p"/tickets")

    # Ticket ID alone is rejected before any lookup happens.
    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "phone" => ""})
      |> render_submit()

    refute html =~ "Private Passenger"
    assert html =~ "Enter the ticket ID"

    # A partial phone number is rejected too.
    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "phone" => "5678"})
      |> render_submit()

    refute html =~ "Private Passenger"

    # Wrong full number reveals nothing.
    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "phone" => "0700000000"})
      |> render_submit()

    refute html =~ "Private Passenger"
    assert html =~ "No ticket matches"

    # The correct full number reveals the ticket.
    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "phone" => "0712345678"})
      |> render_submit()

    assert html =~ "Private Passenger"
    assert html =~ ticket.ticket_id
  end

  test "the full number works across common Kenyan formats", %{conn: conn} do
    ticket = ticket_fixture(%{passenger_phone: "+254712345678"})

    for phone <- ["0712345678", "254712345678", "+254 712 345 678", "712345678"] do
      {:ok, view, _html} = live(conn, ~p"/tickets")

      html =
        view
        |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "phone" => phone})
        |> render_submit()

      assert html =~ "Private Passenger", "expected #{phone} to match"
    end
  end

  test "a signed-in passenger can view their own ticket without entering a phone", %{conn: conn} do
    user = user_fixture(%{phone: "0712345678"})
    ticket = ticket_fixture(%{passenger_name: user.name, passenger_phone: user.phone})

    conn = Plug.Test.init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/tickets")

    html =
      view
      |> form("#ticket-search-form", %{"query" => ticket.ticket_id, "phone" => ""})
      |> render_submit()

    assert html =~ user.name
    assert html =~ ticket.ticket_id
  end

  test "a signed share/payment link token opens the ticket without the phone", %{conn: conn} do
    ticket = ticket_fixture(%{passenger_name: "Token Passenger"})
    path = TicketAccess.path(ticket)

    {:ok, _view, html} = live(conn, path)

    assert html =~ "Token Passenger"
    assert html =~ ticket.ticket_id
    assert html =~ "Boarding QR code"
    assert html =~ "Ticket barcode #{ticket.ticket_id}"
  end

  test "a tampered token does not open the ticket", %{conn: conn} do
    ticket = ticket_fixture(%{passenger_name: "Token Passenger"})

    {:ok, _view, html} =
      live(conn, ~p"/tickets?ticket_id=#{ticket.ticket_id}&token=not-a-real-token")

    refute html =~ "Token Passenger"
    assert html =~ "No ticket matches"
  end
end
