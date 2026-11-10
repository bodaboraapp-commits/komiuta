defmodule XpressbusWeb.AdminRefundsLiveTest do
  @moduledoc """
  The Refunds admin page lists the recorded `ticket_refunds` joined to their
  tickets, with search and totals.
  """

  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.{Ticket, TicketRefund}

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  defp refund_fixture(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    ticket =
      Repo.insert!(%Ticket{
        ticket_id: "TKT-REF-#{unique}",
        from: "Nairobi",
        to: "Kisumu",
        travel_date: ~D[2026-11-20],
        departure: "9:00 AM",
        arrival: "3:00 PM",
        company: "Refund Coaches",
        price: "KES 1,800",
        seats: "[\"2B\"]",
        passenger_name: "Refund Passenger #{unique}",
        passenger_phone: "07123000#{String.pad_leading(to_string(rem(unique, 100)), 2, "0")}",
        payment_method: "mpesa",
        status: "cancelled",
        type: "One Way"
      })

    refund =
      %TicketRefund{}
      |> TicketRefund.changeset(
        Map.merge(
          %{
            ticket_id: ticket.ticket_id,
            amount: 1800,
            reason: "Operator cancelled the trip",
            reference: "REF-#{unique}",
            status: "refunded",
            email_sent: true,
            sms_sent: true
          },
          attrs
        )
      )
      |> Repo.insert!()

    {refund, ticket}
  end

  test "non-admin users are sent to the admin login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, ~p"/admin/refunds")
  end

  test "lists refunds with ticket details, notification flags and totals", %{conn: conn} do
    {refund, ticket} = refund_fixture()

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/refunds")

    assert has_element?(view, "#refund-row-#{refund.ticket_id}")

    html = render(view)
    assert html =~ ticket.ticket_id
    assert html =~ ticket.passenger_name
    assert html =~ "KES 1800"
    assert html =~ refund.reference
    assert html =~ "Refund history"
    refute html =~ "No refunds yet"
  end

  test "search narrows the refund list", %{conn: conn} do
    {_refund, ticket} = refund_fixture()

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/refunds")

    filtered =
      view
      |> form("#refund-search-form", %{"search" => ticket.passenger_name})
      |> render_change()

    assert filtered =~ ticket.ticket_id

    empty =
      view
      |> form("#refund-search-form", %{"search" => "no-such-refund"})
      |> render_change()

    assert empty =~ "No refunds yet"
  end

  test "shows the empty state when there are no refunds", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/refunds")

    html = render(view)
    assert html =~ "No refunds yet"
    assert html =~ "0 total"
  end

  test "sidebar shows Tickets and Refunds split inside the bus section", %{conn: conn} do
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/refunds")

    html = render(view)

    assert html =~ ~s(href="/admin/tickets")
    assert html =~ ~s(href="/admin/refunds")
    assert html =~ "Tickets"
    assert html =~ "Refunds"
    refute html =~ "Tickets &amp; Refunds"
    refute html =~ "Tickets & Refunds"
  end
end
