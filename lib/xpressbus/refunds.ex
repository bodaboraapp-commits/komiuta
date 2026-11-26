defmodule Xpressbus.Refunds do
  @moduledoc """
  Customer refund requests, controlled admin decisions and retention outcomes.

  A refund starts as a request. Customers can track it, accept a retention
  alternative (travel credit or keeping the booking) or withdraw it. Only an
  admin can approve, reject or mark a refund paid, and every transition writes
  an immutable event so operations has a complete audit trail.
  """

  import Ecto.Query

  alias Xpressbus.{Accounts, Payments, Repo, TicketAccess, Tickets}
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Tickets.{Ticket, TicketRefund, TicketRefundEvent}

  @open_statuses TicketRefund.open_statuses()
  @credit_percent 5

  @doc "Requests a refund for a ticket. Only one open request per ticket is allowed."
  def request_refund(%Ticket{} = ticket, attrs) do
    ticket = Tickets.get_ticket(ticket.ticket_id) || ticket
    attrs = normalize(attrs)
    amount = Tickets.parse_amount(attrs["amount"]) || amount_for(ticket)
    reason = String.trim(to_string(attrs["reason"] || ""))
    email = String.trim(to_string(attrs["email"] || customer_email(ticket) || ""))
    payment = Payments.completed_payment_for_ticket(ticket.ticket_id)
    confirmation_code = Payments.confirmation_code(payment)

    with :ok <- ensure_refundable(ticket),
         :ok <- ensure_completed_payment(payment),
         :ok <- ensure_confirmation_code(confirmation_code),
         :ok <- ensure_no_open_request(ticket.ticket_id),
         :ok <- validate_amount(amount, ticket),
         :ok <- validate_reason(reason) do
      result =
        Repo.transaction(fn ->
          # Serialize requests for the same ticket so two simultaneous browser
          # submissions cannot both create an open refund.
          _ticket =
            Repo.one!(
              from(t in Ticket,
                where: t.ticket_id == ^ticket.ticket_id,
                lock: "FOR UPDATE"
              )
            )

          case ensure_no_open_request(ticket.ticket_id) do
            :ok ->
              refund =
                %TicketRefund{}
                |> TicketRefund.changeset(%{
                  ticket_id: ticket.ticket_id,
                  payment_id: payment.id,
                  payment_confirmation_code: confirmation_code,
                  amount: amount,
                  reason: reason,
                  customer_email: email,
                  status: "requested",
                  resolution: "refund"
                })
                |> Repo.insert!()

              _event =
                record_event(refund, "requested", "customer", ticket.passenger_phone, reason)

              refund

            {:error, reason} ->
              Repo.rollback(reason)
          end
        end)

      case result do
        {:ok, refund} ->
          refund = notify(:requested, ticket, refund)
          {:ok, refund}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Returns the latest refund for a ticket, with its audit events."
  def latest_for_ticket(ticket_id) when is_binary(ticket_id) do
    TicketRefund
    |> where([r], r.ticket_id == ^ticket_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> preload(:events)
    |> Repo.one()
  end

  @doc "Returns every refund for a ticket, newest first."
  def for_ticket(ticket_id) when is_binary(ticket_id) do
    TicketRefund
    |> where([r], r.ticket_id == ^ticket_id)
    |> order_by([r], desc: r.inserted_at)
    |> preload(:events)
    |> Repo.all()
  end

  @doc "All requests that still need an admin decision."
  def open_requests do
    TicketRefund
    |> where([r], r.status in ^@open_statuses)
    |> order_by([r], asc: r.inserted_at)
    |> preload(:events)
    |> Repo.all()
  end

  @doc "Paginated refund history for the admin screen."
  def paginate(page, page_size, status \\ nil) do
    base =
      from(r in TicketRefund,
        order_by: [desc: r.inserted_at],
        preload: [:events]
      )

    base =
      case status do
        nil -> base
        "" -> base
        value -> where(base, [r], r.status == ^value)
      end

    total = Repo.aggregate(base, :count, :id)

    entries =
      base
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    {entries, total}
  end

  def get_refund(id) when is_binary(id) do
    TicketRefund
    |> where([r], r.id == ^id)
    |> preload(:events)
    |> Repo.one()
  end

  def stats do
    counts =
      TicketRefund
      |> group_by([r], r.status)
      |> select([r], {r.status, count(r.id)})
      |> Repo.all()
      |> Map.new()

    refunded_amount =
      TicketRefund
      |> where([r], r.status == "refunded")
      |> select([r], coalesce(sum(r.amount), 0))
      |> Repo.one()

    retained = Map.get(counts, "retained", 0)
    refunded = Map.get(counts, "refunded", 0)
    decided = retained + refunded

    %{
      pending: Map.get(counts, "requested", 0) + Map.get(counts, "under_review", 0),
      approved: Map.get(counts, "approved", 0) + Map.get(counts, "processing", 0),
      refunded: refunded,
      retained: retained,
      rejected: Map.get(counts, "rejected", 0) + Map.get(counts, "withdrawn", 0),
      refunded_amount: to_integer_amount(refunded_amount),
      retention_rate: if(decided == 0, do: 0, else: round(retained / decided * 100))
    }
  end

  @doc "Customer accepts travel credit instead of a cash refund."
  def accept_credit(%Ticket{} = ticket, %TicketRefund{} = refund) do
    refund = Repo.get!(TicketRefund, refund.id)

    with :ok <- transitionable(refund) do
      credit_amount = round(refund.amount * (1 + @credit_percent / 100))
      code = credit_code(refund)

      result =
        Repo.transaction(fn ->
          updated =
            refund
            |> TicketRefund.changeset(%{
              status: "retained",
              resolution: "travel_credit",
              retention_offer: "#{@credit_percent}_percent_credit",
              retention_accepted_at: now(),
              credit_code: code,
              amount_approved: credit_amount,
              processed_at: now()
            })
            |> Repo.update!()

          record_event(
            updated,
            "retained",
            "customer",
            ticket.passenger_phone,
            "Accepted #{@credit_percent}% travel credit (#{code})"
          )

          updated
        end)

      case result do
        {:ok, updated} ->
          updated = notify(:retained, ticket, updated)
          {:ok, updated}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Customer keeps the booking and withdraws the refund request."
  def keep_booking(%Ticket{} = ticket, %TicketRefund{} = refund) do
    refund = Repo.get!(TicketRefund, refund.id)

    with :ok <- transitionable(refund) do
      result =
        Repo.transaction(fn ->
          updated =
            refund
            |> TicketRefund.changeset(%{
              status: "withdrawn",
              resolution: "kept_ticket",
              retention_accepted_at: now()
            })
            |> Repo.update!()

          record_event(
            updated,
            "withdrawn",
            "customer",
            ticket.passenger_phone,
            "Customer kept the booking"
          )

          updated
        end)

      case result do
        {:ok, updated} ->
          updated = notify(:withdrawn, ticket, updated)
          {:ok, updated}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc "Admin approval. The approved amount cannot exceed the customer request."
  def approve(refund, admin_id, attrs \\ %{}) do
    attrs = normalize(attrs)
    approved_amount = Tickets.parse_amount(attrs["amount"]) || refund.amount

    cond do
      refund.status not in ["requested", "under_review"] ->
        {:error, :invalid_transition}

      approved_amount <= 0 or approved_amount > refund.amount ->
        {:error, :invalid_amount}

      true ->
        result =
          Repo.transaction(fn ->
            updated =
              refund
              |> TicketRefund.changeset(%{
                status: "approved",
                amount_approved: approved_amount,
                reviewed_by: admin_id,
                reviewed_at: now(),
                admin_note: trim_note(attrs["note"])
              })
              |> Repo.update!()

            record_event(
              updated,
              "approved",
              "admin",
              to_string(admin_id),
              trim_note(attrs["note"])
            )

            updated
          end)

        case result do
          {:ok, updated} ->
            updated = notify(:approved, ticket_for(updated), updated)
            {:ok, updated}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc "Admin rejection. A written reason is required."
  def reject(refund, admin_id, attrs) do
    note = trim_note(normalize(attrs)["note"])

    cond do
      refund.status not in ["requested", "under_review"] ->
        {:error, :invalid_transition}

      note == "" ->
        {:error, :reason_required}

      true ->
        result =
          Repo.transaction(fn ->
            updated =
              refund
              |> TicketRefund.changeset(%{
                status: "rejected",
                reviewed_by: admin_id,
                reviewed_at: now(),
                admin_note: note
              })
              |> Repo.update!()

            record_event(updated, "rejected", "admin", to_string(admin_id), note)
            updated
          end)

        case result do
          {:ok, updated} ->
            updated = notify(:rejected, ticket_for(updated), updated)
            {:ok, updated}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc "Marks an approved refund as paid and cancels the ticket."
  def mark_refunded(refund, admin_id, attrs) do
    attrs = normalize(attrs)

    reversal_code =
      String.trim(to_string(attrs["reversal_code"] || attrs["reference"] || ""))

    cond do
      refund.status not in ["approved", "processing"] ->
        {:error, :invalid_transition}

      reversal_code == "" ->
        {:error, :reversal_code_required}

      true ->
        ticket = ticket_for(refund)

        result =
          Repo.transaction(fn ->
            with {:ok, ticket} <- cancel_ticket(ticket, refund, reversal_code),
                 {:ok, _payment} <-
                   refund_payment(ticket, refund, reversal_code),
                 updated <-
                   refund
                   |> TicketRefund.changeset(%{
                     status: "refunded",
                     reference: reversal_code,
                     payment_reversal_code: reversal_code,
                     processed_at: now(),
                     reviewed_by: admin_id,
                     admin_note: trim_note(attrs["note"]),
                     amount: refund.amount_approved || refund.amount
                   })
                   |> Repo.update!() do
              record_event(
                updated,
                "refunded",
                "admin",
                to_string(admin_id),
                "Reversal code: #{reversal_code}"
              )

              updated
            else
              {:error, reason} -> Repo.rollback(reason)
            end
          end)

        case result do
          {:ok, updated} ->
            updated = notify(:refunded, ticket_for(updated), updated)
            {:ok, updated}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  def status_label("requested"), do: "Requested"
  def status_label("under_review"), do: "Under review"
  def status_label("approved"), do: "Approved"
  def status_label("processing"), do: "Processing"
  def status_label("refunded"), do: "Refunded"
  def status_label("rejected"), do: "Declined"
  def status_label("retained"), do: "Travel credit"
  def status_label("withdrawn"), do: "Withdrawn"
  def status_label("refund_pending"), do: "Pending"
  def status_label(other), do: to_string(other)

  def open?(%TicketRefund{status: status}), do: status in @open_statuses

  defp ensure_refundable(%Ticket{status: "cancelled"}), do: {:error, :already_cancelled}
  defp ensure_refundable(%Ticket{}), do: :ok

  defp ensure_completed_payment(nil), do: {:error, :payment_not_completed}
  defp ensure_completed_payment(%Payment{status: "success"}), do: :ok
  defp ensure_completed_payment(_payment), do: {:error, :payment_not_completed}

  defp ensure_confirmation_code(code) when is_binary(code) and code != "", do: :ok
  defp ensure_confirmation_code(_code), do: {:error, :payment_confirmation_missing}

  defp ensure_no_open_request(ticket_id) do
    exists? =
      TicketRefund
      |> where([r], r.ticket_id == ^ticket_id and r.status in ^@open_statuses)
      |> Repo.exists?()

    if exists?, do: {:error, :already_requested}, else: :ok
  end

  defp validate_amount(amount, ticket) do
    paid = amount_for(ticket)

    cond do
      amount <= 0 -> {:error, :invalid_amount}
      paid > 0 and amount > paid -> {:error, :amount_exceeds_paid}
      true -> :ok
    end
  end

  defp validate_reason(reason) when byte_size(reason) < 5, do: {:error, :reason_required}
  defp validate_reason(_reason), do: :ok

  defp transitionable(refund) do
    if refund.status in ["requested", "under_review"],
      do: :ok,
      else: {:error, :invalid_transition}
  end

  defp amount_for(%Ticket{price: price}), do: Tickets.parse_amount(price) || 0

  defp customer_email(ticket) do
    case Accounts.get_user_by_phone(ticket.passenger_phone) do
      %{email: email} -> email
      _ -> nil
    end
  end

  defp ticket_for(refund), do: Tickets.get_ticket(refund.ticket_id)

  defp cancel_ticket(ticket, refund, reference) do
    ticket
    |> Ticket.changeset(%{
      status: "cancelled",
      cancelled_at: now(),
      cancellation_reason: refund.reason,
      refund_amount: refund.amount_approved || refund.amount,
      refund_reference: reference
    })
    |> Repo.update()
  end

  defp refund_payment(ticket, refund, reversal_code) do
    case Payments.completed_payment_for_ticket(ticket.ticket_id) do
      nil ->
        {:error, :payment_not_completed}

      %Payment{} = payment ->
        raw = payment.raw_response || %{}

        raw =
          Map.put(raw, "refund", %{
            "amount" => refund.amount_approved || refund.amount,
            "confirmation_code" => refund.payment_confirmation_code,
            "reversal_code" => reversal_code,
            "refunded_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          })

        payment
        |> Payment.changeset(%{status: "cancelled", raw_response: raw})
        |> Repo.update()
    end
  end

  defp record_event(refund, status, actor_type, actor_id, note) do
    %TicketRefundEvent{}
    |> TicketRefundEvent.changeset(%{
      refund_id: refund.id,
      status: status,
      actor_type: actor_type,
      actor_id: to_string(actor_id || ""),
      note: note,
      metadata: %{}
    })
    |> Repo.insert!()
  end

  defp notify(_kind, nil, refund), do: refund

  defp notify(kind, ticket, refund) do
    result = Xpressbus.RefundEmail.deliver(kind, ticket, refund)

    details =
      case result do
        :ok -> %{"email" => "sent"}
        {:error, reason} -> %{"email" => to_string(reason)}
        _ -> %{"email" => "unknown"}
      end

    refund
    |> TicketRefund.changeset(%{
      email_sent: result == :ok,
      notification_details: Map.merge(refund.notification_details || %{}, details)
    })
    |> Repo.update()
    |> case do
      {:ok, updated} -> updated
      {:error, _} -> refund
    end
  end

  defp credit_code(_refund) do
    suffix =
      :crypto.strong_rand_bytes(5)
      |> Base.encode32(case: :upper, padding: false)
      |> binary_part(0, 8)

    "KOMIUTA-CREDIT-#{suffix}"
  end

  defp normalize(attrs) when is_map(attrs) do
    for {key, value} <- attrs, into: %{}, do: {to_string(key), value}
  end

  defp normalize(_attrs), do: %{}

  defp trim_note(nil), do: ""
  defp trim_note(note), do: note |> to_string() |> String.trim()

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp to_integer_amount(%Decimal{} = amount), do: Decimal.to_integer(amount)
  defp to_integer_amount(amount) when is_integer(amount), do: amount
  defp to_integer_amount(_amount), do: 0

  @doc "Signed customer tracking URL for a refund."
  def path(%Ticket{} = ticket), do: TicketAccess.refund_path(ticket)
end
