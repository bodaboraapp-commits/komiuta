defmodule Xpressbus.RefundsTest do
  use Xpressbus.DataCase, async: false

  import Swoosh.TestAssertions

  alias Xpressbus.Refunds
  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  @ticket_attrs %{
    from: "Nairobi",
    to: "Mombasa",
    travel_date: ~D[2026-12-15],
    departure: "08:00 AM",
    arrival: "02:00 PM",
    company: "Test Coach",
    price: "KES 1,800",
    seats: "4,5",
    passenger_name: "Refund Passenger",
    passenger_phone: "0712345678",
    status: "confirmed"
  }

  defp ticket_fixture(attrs \\ %{}) do
    attrs = Map.merge(@ticket_attrs, attrs)
    ticket_id = "TKT-REFUND-#{System.unique_integer([:positive])}"

    %Ticket{}
    |> Ticket.changeset(Map.put(attrs, :ticket_id, ticket_id))
    |> Repo.insert!()
  end

  defp request(ticket, attrs \\ %{}) do
    Refunds.request_refund(
      ticket,
      Map.merge(
        %{
          "amount" => "1800",
          "reason" => "My plans changed and I cannot travel",
          "email" => "refund@example.com"
        },
        attrs
      )
    )
  end

  describe "customer request" do
    test "creates a tracked request and sends an acknowledgement" do
      ticket = ticket_fixture()

      assert {:ok, refund} = request(ticket)

      assert refund.status == "requested"
      assert refund.amount == 1800
      assert refund.customer_email == "refund@example.com"
      assert [event] = Refunds.get_refund(refund.id).events
      assert event.status == "requested"
      assert event.actor_type == "customer"

      assert_email_sent(fn email ->
        assert email.subject =~ "refund request"
        assert email.text_body =~ ticket.ticket_id
      end)
    end

    test "rejects duplicate open requests" do
      ticket = ticket_fixture()
      assert {:ok, _refund} = request(ticket)
      assert {:error, :already_requested} = request(ticket)
    end

    test "caps the request at the amount paid" do
      ticket = ticket_fixture()

      assert {:error, :amount_exceeds_paid} =
               request(ticket, %{"amount" => "5000"})
    end

    test "requires a meaningful reason" do
      ticket = ticket_fixture()

      assert {:error, :reason_required} =
               request(ticket, %{"reason" => "x"})
    end
  end

  describe "retention" do
    test "customer can accept travel credit instead of a cash refund" do
      ticket = ticket_fixture()
      {:ok, refund} = request(ticket)

      assert {:ok, retained} = Refunds.accept_credit(ticket, refund)
      assert retained.status == "retained"
      assert retained.resolution == "travel_credit"
      assert retained.credit_code =~ "KOMIUTA-CREDIT-"
      assert retained.amount_approved == 1890
      assert ticket.status == "confirmed"
      assert Enum.any?(Refunds.get_refund(retained.id).events, &(&1.status == "retained"))
    end

    test "customer can keep the booking and withdraw the request" do
      ticket = ticket_fixture()
      {:ok, refund} = request(ticket)

      assert {:ok, withdrawn} = Refunds.keep_booking(ticket, refund)
      assert withdrawn.status == "withdrawn"
      assert withdrawn.resolution == "kept_ticket"
      assert ticket.status == "confirmed"
    end
  end

  describe "admin controls" do
    test "approval requires the amount to stay within the request" do
      ticket = ticket_fixture()
      {:ok, refund} = request(ticket)

      assert {:error, :invalid_amount} = Refunds.approve(refund, 1, %{"amount" => "2000"})

      assert {:ok, approved} =
               Refunds.approve(refund, 1, %{"amount" => "1500", "note" => "Goodwill"})

      assert approved.status == "approved"
      assert approved.amount_approved == 1500
      assert approved.reviewed_by == 1
      assert approved.admin_note == "Goodwill"
      assert Enum.any?(Refunds.get_refund(approved.id).events, &(&1.status == "approved"))
    end

    test "rejection requires a reason and records it" do
      ticket = ticket_fixture()
      {:ok, refund} = request(ticket)

      assert {:error, :reason_required} = Refunds.reject(refund, 1, %{})

      assert {:ok, rejected} = Refunds.reject(refund, 1, %{"note" => "Outside fare rules"})
      assert rejected.status == "rejected"
      assert rejected.admin_note == "Outside fare rules"
    end

    test "marking refunded requires a reference and cancels the ticket" do
      ticket = ticket_fixture()
      {:ok, refund} = request(ticket)
      {:ok, refund} = Refunds.approve(refund, 1, %{"amount" => "1800"})

      assert {:error, :reference_required} = Refunds.mark_refunded(refund, 1, %{})

      assert {:ok, refunded} =
               Refunds.mark_refunded(refund, 1, %{
                 "reference" => "REF-123",
                 "note" => "Paid manually"
               })

      assert refunded.status == "refunded"
      assert refunded.reference == "REF-123"
      assert refunded.processed_at
      cancelled = Repo.get_by!(Ticket, ticket_id: ticket.ticket_id)
      assert cancelled.status == "cancelled"
      assert cancelled.refund_reference == "REF-123"
      assert cancelled.refund_amount == 1800
      assert Enum.any?(Refunds.get_refund(refunded.id).events, &(&1.status == "refunded"))
    end

    test "stats include pending, refunded and retained requests" do
      first = ticket_fixture()
      second = ticket_fixture()
      third = ticket_fixture()
      {:ok, refund} = request(first)
      {:ok, _} = request(second)
      {:ok, third_refund} = request(third)

      Refunds.accept_credit(third, third_refund)
      {:ok, approved} = Refunds.approve(refund, 1, %{})
      {:ok, _} = Refunds.mark_refunded(approved, 1, %{"reference" => "REF-STATS"})

      stats = Refunds.stats()
      assert stats.pending == 1
      assert stats.refunded == 1
      assert stats.retained == 1
      assert stats.refunded_amount == 1800
    end
  end

  test "only open requests can be decided" do
    ticket = ticket_fixture()
    {:ok, refund} = request(ticket)
    {:ok, refund} = Refunds.reject(refund, 1, %{"note" => "Declined"})

    assert {:error, :invalid_transition} = Refunds.approve(refund, 1, %{})
  end
end
