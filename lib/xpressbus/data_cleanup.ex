defmodule Xpressbus.DataCleanup do
  @moduledoc """
  Maintenance helpers for stale booking data.

  A ticket is created with status `pending` before its payment is confirmed.
  When a payment is abandoned (user closes M-PESA, provider timeout, etc.) the
  ticket and its payment attempt stay behind, cluttering the user dashboard and
  the admin payment list.

  `clear_stale_pending_bookings/2` removes such rows, but is deliberately
  conservative:

    * only tickets with `status = "pending"` created **before** the cutoff are
      touched (bookings from today are never removed);
    * a pending ticket that has a `success` payment is **kept** (that is a
      paid booking with an inconsistent status and must be investigated, not
      deleted);
    * every row is copied into `pending_booking_archive` (JSON snapshot) inside
      the same transaction before it is deleted, so the cleanup is reversible.
  """

  import Ecto.Query

  alias Xpressbus.Repo

  @archive_table "pending_booking_archive"
  @batch_size 500
  @protected_payment_status "success"

  # Selected explicitly instead of using the Ecto schemas: cleanup must keep
  # working while the schema is being migrated (and must not depend on columns
  # that a newer, not-yet-deployed schema version expects).
  @ticket_fields [
    :ticket_id,
    :from,
    :to,
    :travel_date,
    :departure,
    :arrival,
    :company,
    :price,
    :seats,
    :passenger_name,
    :passenger_phone,
    :payment_method,
    :status,
    :bus_id,
    :type,
    :inserted_at,
    :updated_at
  ]

  @payment_fields [
    :id,
    :provider,
    :amount,
    :currency,
    :status,
    :reference,
    :ticket_id,
    :phone_number,
    :inserted_at,
    :updated_at
  ]

  @type summary :: %{
          tickets: non_neg_integer(),
          payments: non_neg_integer(),
          protected: non_neg_integer(),
          dry_run: boolean()
        }

  @doc """
  Archives and deletes pending tickets created before `cutoff` plus the payment
  attempts linked to them.

  Options:

    * `:dry_run` - when `true`, only counts what would be removed and changes
      nothing (default `false`).

  Returns `%{tickets: n, payments: n, protected: n, dry_run: boolean}`.
  `:protected` is the number of pending tickets that were kept because they
  have a successful payment.
  """
  @spec clear_stale_pending_bookings(DateTime.t(), keyword()) :: summary()
  def clear_stale_pending_bookings(%DateTime{} = cutoff, opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, false)
    {ticket_ids, protected_count} = eligible_ticket_ids(cutoff)

    if dry_run? do
      %{
        tickets: length(ticket_ids),
        payments: count_linked_payments(ticket_ids),
        protected: protected_count,
        dry_run: true
      }
    else
      summary =
        Repo.transaction(fn ->
          archive_and_delete_in_batches(ticket_ids)
        end)

      case summary do
        {:ok, result} ->
          Map.merge(result, %{protected: protected_count, dry_run: false})

        {:error, reason} ->
          raise "stale pending booking cleanup failed: #{inspect(reason)}"
      end
    end
  end

  @doc """
  Cutoff for "before today" in East Africa Time (UTC+3, no DST).

  Returns the UTC instant corresponding to 00:00 Africa/Nairobi today, e.g.
  `2026-11-05 21:00:00Z` on 2026-11-06.
  """
  @spec cutoff_for_today(DateTime.t()) :: DateTime.t()
  def cutoff_for_today(now \\ DateTime.utc_now()) do
    # Shift into EAT to read the local calendar date, then convert local
    # midnight back to UTC (midnight EAT is the previous day at 21:00 UTC).
    local_date = now |> DateTime.add(3 * 3600, :second) |> DateTime.to_date()

    DateTime.new!(Date.add(local_date, -1), ~T[21:00:00], "Etc/UTC")
  end

  # --- Selection -------------------------------------------------------------

  defp eligible_ticket_ids(cutoff) do
    pending_ids =
      Repo.all(
        from(t in "tickets",
          where: t.status == "pending" and t.inserted_at < ^cutoff,
          select: t.ticket_id
        )
      )

    protected_ids =
      pending_ids
      |> case do
        [] ->
          []

        ids ->
          Repo.all(
            from(p in "payments",
              where: p.ticket_id in ^ids and p.status == @protected_payment_status,
              select: p.ticket_id
            )
          )
      end
      |> MapSet.new()

    eligible = Enum.reject(pending_ids, &MapSet.member?(protected_ids, &1))
    {eligible, MapSet.size(protected_ids)}
  end

  defp count_linked_payments([]), do: 0

  defp count_linked_payments(ticket_ids) do
    Repo.aggregate(from(p in "payments", where: p.ticket_id in ^ticket_ids), :count, :id)
  end

  # --- Archive + delete ------------------------------------------------------

  defp archive_and_delete_in_batches(ticket_ids) do
    archived_at = DateTime.utc_now() |> DateTime.truncate(:second)

    ticket_ids
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce(%{tickets: 0, payments: 0}, fn batch, acc ->
      tickets =
        Repo.all(
          from(t in "tickets", where: t.ticket_id in ^batch, select: map(t, @ticket_fields))
        )

      payments =
        Repo.all(
          from(p in "payments", where: p.ticket_id in ^batch, select: map(p, @payment_fields))
        )

      archive_rows(tickets, payments, archived_at)

      {payments_deleted, _} =
        Repo.delete_all(from(p in "payments", where: p.ticket_id in ^batch))

      {tickets_deleted, _} =
        Repo.delete_all(
          from(t in "tickets", where: t.ticket_id in ^batch and t.status == "pending")
        )

      %{
        tickets: acc.tickets + tickets_deleted,
        payments: acc.payments + payments_deleted
      }
    end)
  end

  defp archive_rows(tickets, payments, archived_at) do
    rows =
      Enum.map(tickets, fn ticket ->
        %{
          kind: "ticket",
          ticket_id: ticket.ticket_id,
          reference: nil,
          payload: ticket_payload(ticket),
          archived_at: archived_at
        }
      end) ++
        Enum.map(payments, fn payment ->
          %{
            kind: "payment",
            ticket_id: payment.ticket_id,
            reference: payment.reference,
            payload: payment_payload(payment),
            archived_at: archived_at
          }
        end)

    if rows != [], do: Repo.insert_all(@archive_table, rows)
    :ok
  end

  defp ticket_payload(ticket) do
    %{
      ticket_id: ticket.ticket_id,
      from: ticket.from,
      to: ticket.to,
      travel_date: iso(ticket.travel_date),
      departure: ticket.departure,
      arrival: ticket.arrival,
      company: ticket.company,
      price: ticket.price,
      seats: ticket.seats,
      passenger_name: ticket.passenger_name,
      passenger_phone: ticket.passenger_phone,
      payment_method: ticket.payment_method,
      status: ticket.status,
      bus_id: ticket.bus_id,
      type: ticket.type,
      inserted_at: iso(ticket.inserted_at),
      updated_at: iso(ticket.updated_at)
    }
  end

  defp payment_payload(payment) do
    %{
      id: Base.encode16(payment.id, case: :lower),
      provider: payment.provider,
      amount: payment.amount,
      currency: payment.currency,
      status: payment.status,
      reference: payment.reference,
      ticket_id: payment.ticket_id,
      phone_number: payment.phone_number,
      inserted_at: iso(payment.inserted_at),
      updated_at: iso(payment.updated_at)
    }
  end

  defp iso(nil), do: nil
  defp iso(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp iso(%Date{} = value), do: Date.to_iso8601(value)
  defp iso(value), do: to_string(value)
end
