defmodule XpressbusWeb.RefundLiveTest do
  use XpressbusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Xpressbus.{Repo, TicketAccess}
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Tickets.Ticket

  defp ticket_fixture do
    attrs = %{
      ticket_id: "TKT-LIVE-REFUND-#{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Kisumu",
      travel_date: ~D[2026-12-20],
      departure: "09:00 AM",
      arrival: "03:00 PM",
      company: "Test Coach",
      price: "KES 2,000",
      seats: "1",
      passenger_name: "Live Refund Passenger",
      passenger_phone: "0712000111",
      status: "confirmed"
    }

    %Ticket{} |> Ticket.changeset(attrs) |> Repo.insert!()
  end

  defp payment_fixture(ticket) do
    %Payment{}
    |> Payment.changeset(%{
      provider: "mpesa",
      amount: 2000,
      reference: "PAY-LIVE-#{System.unique_integer([:positive])}",
      phone_number: "0712000111",
      ticket_id: ticket.ticket_id,
      status: "success",
      raw_response: %{
        "MpesaReceiptNumber" => "LIVE-RECEIPT-#{System.unique_integer([:positive])}"
      }
    })
    |> Repo.insert!()
  end

  defp paid_ticket_fixture do
    ticket = ticket_fixture()
    payment_fixture(ticket)
    ticket
  end

  test "customer can open the signed refund page and submit a request", %{conn: conn} do
    ticket = paid_ticket_fixture()
    path = "/refunds/#{ticket.ticket_id}?token=#{TicketAccess.token(ticket)}"

    {:ok, view, html} = live(conn, path)
    assert html =~ "Need to change your plans?"
    assert has_element?(view, "#refund-request-form")

    view
    |> form("#refund-request-form", %{
      "refund" => %{
        "amount" => "2000",
        "email" => "live-refund@example.com",
        "reason" => "My travel plans changed"
      }
    })
    |> render_submit()

    html = render(view)
    assert html =~ "Track your refund"
    assert html =~ "Requested"
    assert has_element?(view, "#refund-timeline")
  end

  test "refund form is blocked without a completed payment", %{conn: conn} do
    ticket = ticket_fixture()
    path = "/refunds/#{ticket.ticket_id}?token=#{TicketAccess.token(ticket)}"

    {:ok, view, _html} = live(conn, path)

    assert has_element?(view, "#refund-payment-required")
    refute has_element?(view, "#refund-request-form")
  end

  test "a tampered refund token is rejected", %{conn: conn} do
    ticket = ticket_fixture()

    assert {:error, {:live_redirect, %{to: "/tickets"}}} =
             live(conn, "/refunds/#{ticket.ticket_id}?token=not-valid")
  end

  test "admin sees pending refund requests with review controls", %{conn: conn} do
    {:ok, admin} =
      Xpressbus.Admins.create_admin(%{
        email: "refund-admin@example.com",
        name: "Refund Admin",
        hashed_password: Xpressbus.Admins.hash_password("secret-password")
      })

    ticket = paid_ticket_fixture()

    {:ok, refund} =
      Xpressbus.Refunds.request_refund(ticket, %{
        "amount" => "2000",
        "reason" => "Customer needs to cancel",
        "email" => "customer@example.com"
      })

    conn = init_test_session(conn, %{"admin_id" => admin.id})
    {:ok, view, html} = live(conn, ~p"/admin/refund-requests")

    assert html =~ "Refund requests"
    assert has_element?(view, "#refund-pending-count")
    assert has_element?(view, "#refund-requests")
    assert has_element?(view, "[id^='approve-refund-']")
    assert has_element?(view, "[id^='reject-refund-']")

    view |> element("#approve-refund-#{refund.id}") |> render_click()
    assert has_element?(view, "#approve-refund-form")

    view
    |> form("#approve-refund-form", %{"refund" => %{"amount" => "2000", "note" => "Verified"}})
    |> render_submit()

    assert Xpressbus.Refunds.get_refund(refund.id).status == "approved"
  end
end
