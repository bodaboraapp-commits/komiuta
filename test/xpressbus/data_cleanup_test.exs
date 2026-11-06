defmodule Xpressbus.DataCleanupTest do
  @moduledoc """
  Tests for the stale pending booking cleanup.

  The cleanup must remove abandoned pending bookings (and their payment
  attempts) while never touching confirmed bookings, bookings created after the
  cutoff, or a pending ticket that actually has a successful payment.
  """

  use Xpressbus.DataCase, async: false

  import Ecto.Query

  alias Xpressbus.DataCleanup
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  @cutoff ~U[2026-11-06 00:00:00Z]

  setup do
    Repo.delete_all(from(a in "pending_booking_archive"))
    :ok
  end

  defp stale_time, do: DateTime.add(@cutoff, -3 * 24 * 60 * 60)

  defp ticket_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          ticket_id: "TKT-#{System.unique_integer([:positive])}",
          from: "Nairobi",
          to: "Mombasa",
          travel_date: ~D[2026-11-01],
          departure: "7:00 AM",
          arrival: "3:00 PM",
          company: "Test Operator",
          price: "KSH 1000",
          seats: "[\"1\"]",
          passenger_name: "Cleanup Test",
          passenger_phone: "0712345678",
          payment_method: "mpesa",
          status: "pending",
          type: "One Way"
        },
        attrs
      )

    ticket = Repo.insert!(struct(Ticket, attrs))
    set_ticket_time(ticket, attrs[:created_at] || stale_time())
    ticket
  end

  defp payment_fixture(ticket, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          provider: "mpesa",
          amount: 1000,
          currency: "KES",
          status: "pending",
          reference: "ws_CO_TEST_#{System.unique_integer([:positive])}",
          phone_number: "0712345678",
          ticket_id: ticket.ticket_id
        },
        attrs
      )

    payment = Repo.insert!(struct(Payment, attrs))
    set_payment_time(payment, attrs[:created_at] || stale_time())
    payment
  end

  defp set_ticket_time(ticket, time) do
    Repo.update_all(from(t in Ticket, where: t.id == ^ticket.id), set: [inserted_at: time])
  end

  defp set_payment_time(payment, time) do
    Repo.update_all(from(p in Payment, where: p.id == ^payment.id), set: [inserted_at: time])
  end

  defp archived_rows do
    Repo.all(from(a in "pending_booking_archive", select: a.payload))
    |> Enum.map(fn
      payload when is_binary(payload) -> Jason.decode!(payload)
      payload -> payload
    end)
  end

  test "dry run counts the stale bookings without deleting anything" do
    first = ticket_fixture()
    second = ticket_fixture()
    payment_fixture(first)
    payment_fixture(second, %{status: "failed"})
    ticket_fixture(%{status: "confirmed"})
    ticket_fixture(%{created_at: DateTime.add(@cutoff, 60 * 60)})

    summary = DataCleanup.clear_stale_pending_bookings(@cutoff, dry_run: true)

    assert summary.tickets == 2
    assert summary.payments == 2
    assert summary.protected == 0
    assert summary.dry_run
    assert Repo.get_by(Ticket, ticket_id: first.ticket_id)
    assert Repo.get_by(Ticket, ticket_id: second.ticket_id)
    assert archived_rows() == []
  end

  test "archives and deletes stale pending tickets and their payments only" do
    stale = ticket_fixture()
    stale_other = ticket_fixture()
    stale_payment = payment_fixture(stale)
    stale_other_payment = payment_fixture(stale_other, %{status: "failed"})

    confirmed = ticket_fixture(%{status: "confirmed"})
    confirmed_payment = payment_fixture(confirmed, %{status: "success"})
    recent_pending = ticket_fixture(%{created_at: DateTime.add(@cutoff, 3600)})
    recent_payment = payment_fixture(recent_pending)

    summary = DataCleanup.clear_stale_pending_bookings(@cutoff)

    assert summary.tickets == 2
    assert summary.payments == 2
    refute summary.dry_run

    refute Repo.get_by(Ticket, ticket_id: stale.ticket_id)
    refute Repo.get_by(Ticket, ticket_id: stale_other.ticket_id)
    refute Repo.get_by(Payment, id: stale_payment.id)
    refute Repo.get_by(Payment, id: stale_other_payment.id)

    assert Repo.get_by(Ticket, ticket_id: confirmed.ticket_id)
    assert Repo.get_by(Ticket, ticket_id: recent_pending.ticket_id)
    assert Repo.get_by(Payment, id: confirmed_payment.id)
    assert Repo.get_by(Payment, id: recent_payment.id)

    archived = archived_rows()
    assert length(archived) == 4

    archived_ticket_ids =
      archived
      |> Enum.map(fn
        row when is_binary(row) -> Jason.decode!(row)
        row -> row
      end)
      |> Enum.map(& &1["ticket_id"])
      |> MapSet.new()

    assert MapSet.member?(archived_ticket_ids, stale.ticket_id)
    assert MapSet.member?(archived_ticket_ids, stale_other.ticket_id)
  end

  test "is idempotent" do
    ticket_fixture() |> payment_fixture()

    assert %{tickets: 1, payments: 1} = DataCleanup.clear_stale_pending_bookings(@cutoff)
    assert %{tickets: 0, payments: 0} = DataCleanup.clear_stale_pending_bookings(@cutoff)
  end

  test "keeps a pending ticket that has a successful payment" do
    paid = ticket_fixture()
    payment = payment_fixture(paid, %{status: "success"})

    summary = DataCleanup.clear_stale_pending_bookings(@cutoff)

    assert summary.tickets == 0
    assert summary.payments == 0
    assert summary.protected == 1
    assert Repo.get_by(Ticket, ticket_id: paid.ticket_id)
    assert Repo.get_by(Payment, id: payment.id)
  end

  test "cutoff_for_today is midnight Africa/Nairobi expressed in UTC" do
    # 2026-11-06 08:00 EAT == 2026-11-06 05:00 UTC
    now = ~U[2026-11-06 05:00:00Z]
    assert DataCleanup.cutoff_for_today(now) == ~U[2026-11-05 21:00:00Z]

    # 2026-11-07 01:00 EAT == 2026-11-06 22:00 UTC
    late = ~U[2026-11-06 22:00:00Z]
    assert DataCleanup.cutoff_for_today(late) == ~U[2026-11-05 21:00:00Z] |> DateTime.add(86400)
  end
end
