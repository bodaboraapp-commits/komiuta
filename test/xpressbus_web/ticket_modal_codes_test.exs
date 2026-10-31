defmodule XpressbusWeb.TicketModalCodesTest do
  @moduledoc """
  Regression tests for the boarding codes in the dashboard "Congratulations"
  ticket modal.

  The modal used to render a decorative random-pixel "QR" and a random-width
  "barcode", which were not scannable and changed on every render. It must
  render the same locally generated codes as the public ticket page:
  `Xpressbus.QR` for the signed ticket URL and `Xpressbus.Barcode` (Code 128B)
  for the ticket number.
  """

  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket
  alias XpressbusWeb.TicketCodes

  defp ticket_fixture(attrs) do
    defaults = %{
      ticket_id: "TKT-#{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Kisumu",
      travel_date: ~D[2026-11-01],
      departure: "7:00 AM",
      arrival: "4:00 PM",
      company: "Chania Executive",
      price: "KSH 1500",
      seats: "[\"40\"]",
      passenger_name: "Modal Passenger",
      passenger_phone: "0712345678",
      payment_method: "mpesa",
      status: "confirmed",
      type: "One Way"
    }

    Repo.insert!(struct(Ticket, Map.merge(defaults, attrs)))
  end

  defp user_with_ticket(attrs \\ %{}) do
    user = user_fixture()

    ticket =
      ticket_fixture(Map.merge(%{passenger_name: user.name, passenger_phone: user.phone}, attrs))

    {user, ticket}
  end

  defp signed_in(conn, user) do
    Plug.Test.init_test_session(conn, %{user_id: user.id})
  end

  describe "TicketCodes" do
    test "renders a real QR code for the signed ticket URL" do
      {_user, ticket} = user_with_ticket()

      assert {:safe, svg} = TicketCodes.qr(ticket)
      assert svg =~ ~s(aria-label="Boarding QR code")
      assert svg =~ "<path"
      assert svg =~ ~s(fill="#ffffff")
      assert svg =~ ~s(fill="#000000")
    end

    test "renders a Code 128B barcode for the ticket number" do
      {_user, ticket} = user_with_ticket()

      assert {:safe, svg} = TicketCodes.barcode(ticket)
      assert svg =~ ~s(aria-label="Ticket barcode #{ticket.ticket_id}")
      assert svg =~ "<rect"
      # Fixed-size bars for print/scan reliability.
      refute svg =~ ~s(width="100%")
    end

    test "supports a fluid width for modal containers" do
      {_user, ticket} = user_with_ticket()

      assert {:safe, svg} = TicketCodes.barcode(ticket, responsive: true)
      assert svg =~ ~s(width="100%")
      assert svg =~ ~s(shape-rendering="crispEdges")
    end

    test "returns nil instead of crashing without a ticket" do
      assert TicketCodes.qr(nil) == nil
      assert TicketCodes.barcode(nil) == nil
      assert TicketCodes.download_url(nil) == nil
    end

    test "exposes a signed PDF download URL" do
      {_user, ticket} = user_with_ticket()

      url = TicketCodes.download_url(ticket)

      assert url == Xpressbus.TicketAccess.download_path(ticket)
      assert url =~ "/tickets/#{ticket.ticket_id}/download?token="
    end
  end

  describe "dashboard ticket modal" do
    test "renders the real QR code and Code 128 barcode", %{conn: conn} do
      {user, ticket} = user_with_ticket()

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard")

      html = render_click(view, "view_ticket", %{"ticket_id" => ticket.ticket_id})

      assert html =~ "Congratulations!"
      assert has_element?(view, "#ticket-qr svg")
      assert has_element?(view, "#ticket-barcode svg")
      assert html =~ ~s(aria-label="Boarding QR code")
      assert html =~ ~s(aria-label="Ticket barcode #{ticket.ticket_id}")

      barcode_html = view |> element("#ticket-barcode") |> render()
      assert barcode_html =~ ~s(width="100%")
      assert barcode_html =~ "<rect"
    end

    test "closing the modal removes the codes from the DOM", %{conn: conn} do
      {user, ticket} = user_with_ticket()

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard")

      render_click(view, "view_ticket", %{"ticket_id" => ticket.ticket_id})
      assert has_element?(view, "#ticket-qr")

      render_click(view, "close_ticket")

      refute has_element?(view, "#ticket-qr")
      refute has_element?(view, "#ticket-barcode")
    end

    test "the Download PDF button points at the signed PDF", %{conn: conn} do
      {user, ticket} = user_with_ticket()

      {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard")

      render_click(view, "view_ticket", %{"ticket_id" => ticket.ticket_id})

      link_html = view |> element("#download-ticket-pdf") |> render()

      assert link_html =~ "/tickets/#{ticket.ticket_id}/download"
      assert link_html =~ "token="
    end

    test "the template no longer draws fake codes" do
      template =
        "lib/xpressbus_web/live/user_dashboard_live.html.heex"
        |> File.read!()

      # The old placeholders generated random bars / random QR modules on every
      # render. They must not come back.
      refute template =~ ":rand.uniform"
      refute template =~ "Enum.random([1, 2])"
      refute template =~ "opacity-30"

      assert template =~ "@ticket_qr"
      assert template =~ "@ticket_barcode"
    end
  end
end
