defmodule Xpressbus.Tickets do
  @moduledoc """
  The Tickets context handles ticket tracking and searching.
  """

  import Ecto.Query
  alias Xpressbus.{Accounts, Payments, SMS, TicketCancellationEmail}
  alias Xpressbus.Repo
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Tickets.{Ticket, TicketRefund}

  @doc """
  Cancels a ticket, records a refund and notifies the traveller by SMS and email.

  `attrs` accepts `refund_amount`, `reason` and `reference`. The ticket and
  payment are updated transactionally; notifications happen afterwards so a
  delivery failure cannot roll back a refund.
  """
  def cancel_and_refund(%Ticket{} = ticket, attrs, admin_id \\ nil) do
    # The struct may be stale (e.g. the admin page was opened before another
    # cancellation), so always re-read the current ticket status first.
    ticket = Repo.get_by(Ticket, ticket_id: ticket.ticket_id) || ticket
    attrs = stringify_keys(attrs)
    refund_amount = parse_amount(attrs["refund_amount"]) || parse_amount(ticket.price) || 0
    reason = String.trim(to_string(attrs["reason"] || ""))
    reference = String.trim(to_string(attrs["reference"] || ""))

    cond do
      ticket.status == "cancelled" ->
        {:error, :already_cancelled}

      refund_amount < 0 ->
        {:error, :invalid_amount}

      true ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        result =
          Repo.transaction(fn ->
            with {:ok, ticket} <-
                   ticket
                   |> Ticket.changeset(%{
                     status: "cancelled",
                     cancelled_at: now,
                     cancellation_reason: reason,
                     refund_amount: refund_amount,
                     refund_reference: reference
                   })
                   |> Repo.update(),
                 :ok <- refund_payment(ticket, refund_amount, reference),
                 {:ok, refund} <-
                   %TicketRefund{}
                   |> TicketRefund.changeset(%{
                     ticket_id: ticket.ticket_id,
                     amount: refund_amount,
                     reason: reason,
                     reference: reference,
                     status: "refunded",
                     admin_id: admin_id
                   })
                   |> Repo.insert() do
              {ticket, refund}
            else
              {:error, reason} -> Repo.rollback(reason)
            end
          end)

        case result do
          {:ok, {ticket, refund}} ->
            {refund, notification_results} = notify_traveller(ticket, refund)
            {:ok, Map.put(notification_results, :ticket, ticket) |> Map.put(:refund, refund)}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp notify_traveller(ticket, refund) do
    user = Accounts.get_user_by_phone(ticket.passenger_phone)
    email_result = TicketCancellationEmail.deliver(user, ticket, refund)
    sms_result = SMS.send(ticket.passenger_phone, SMS.body_for_cancellation(ticket, refund))

    details = %{
      "email" => result_description(email_result),
      "sms" => result_description(sms_result)
    }

    refund =
      refund
      |> TicketRefund.changeset(%{
        email_sent: match?({:ok, _}, email_result),
        sms_sent: match?({:ok, _}, sms_result),
        notification_details: details
      })
      |> Repo.update()
      |> case do
        {:ok, updated} -> updated
        {:error, _} -> refund
      end

    {refund,
     %{
       email: email_result,
       sms: sms_result,
       user: user
     }}
  end

  defp refund_payment(ticket, amount, reference) do
    case Payments.get_payment_by_reference(ticket.ticket_id) do
      nil ->
        :ok

      %Payment{} = payment ->
        raw = payment.raw_response || %{}

        raw =
          Map.put(raw, "refund", %{
            "amount" => amount,
            "reference" => reference,
            "refunded_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          })

        payment
        |> Payment.changeset(%{status: "cancelled", raw_response: raw})
        |> Repo.update()
        |> case do
          {:ok, _payment} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp result_description({:ok, _}), do: "sent"
  defp result_description({:error, reason}), do: to_string(reason)
  defp result_description(_), do: "unknown"

  defp stringify_keys(attrs) do
    for {key, value} <- attrs, into: %{}, do: {to_string(key), value}
  end

  @doc "Parses a KES amount from a price string such as \"KSH 1,500\"."
  def parse_amount(value) when is_integer(value), do: value

  def parse_amount(value) when is_binary(value) do
    digits = String.replace(value, ~r/[^0-9]/, "")

    case Integer.parse(digits) do
      {amount, _} -> amount
      :error -> nil
    end
  end

  def parse_amount(_), do: nil

  @doc """
  Paginated ticket list for the admin refunds screen.
  """
  def paginate_admin_tickets(page, page_size, search \\ "") do
    search = String.trim(to_string(search || ""))
    pattern = "%#{search}%"

    query =
      from(t in Ticket,
        order_by: [desc: t.inserted_at]
      )

    query =
      if search == "" do
        query
      else
        where(
          query,
          [t],
          fragment("LOWER(?) LIKE LOWER(?)", t.ticket_id, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", t.passenger_name, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", t.passenger_phone, ^pattern)
        )
      end

    total = Repo.aggregate(query, :count, :id)

    tickets =
      query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()
      |> Enum.map(&deserialize_seats/1)

    {tickets, total}
  end

  def refunds_for_ticket(ticket_id) do
    from(r in TicketRefund,
      where: r.ticket_id == ^ticket_id,
      order_by: [desc: r.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Paginated refund history for the admin refunds page.

  Joins the refund to its ticket so the row can show the passenger and route.
  """
  def paginate_refunds(page, page_size, search \\ "") do
    search = String.trim(to_string(search || ""))
    pattern = "%#{search}%"

    base =
      from(r in TicketRefund,
        join: t in Ticket,
        on: t.ticket_id == r.ticket_id
      )

    base =
      if search == "" do
        base
      else
        where(
          base,
          [r, t],
          fragment("LOWER(?) LIKE LOWER(?)", r.ticket_id, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", r.reference, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", t.passenger_name, ^pattern) or
            fragment("LOWER(?) LIKE LOWER(?)", t.passenger_phone, ^pattern)
        )
      end

    total = Repo.aggregate(base, :count, :id)

    refunds =
      base
      |> select(
        [r, t],
        %{
          id: r.id,
          ticket_id: r.ticket_id,
          amount: r.amount,
          reason: r.reason,
          reference: r.reference,
          status: r.status,
          inserted_at: r.inserted_at,
          email_sent: r.email_sent,
          sms_sent: r.sms_sent,
          passenger_name: t.passenger_name,
          passenger_phone: t.passenger_phone,
          from: t.from,
          to: t.to,
          travel_date: t.travel_date,
          price: t.price
        }
      )
      |> order_by([r], desc: r.inserted_at)
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    {refunds, total}
  end

  @doc "Aggregate refund count and total refunded amount."
  def refund_totals do
    from(r in TicketRefund,
      select: %{count: count(r.id), amount: sum(r.amount)}
    )
    |> Repo.one()
    |> case do
      nil -> %{count: 0, amount: 0}
      %{count: count, amount: amount} -> %{count: count, amount: amount || 0}
    end
  end

  @doc """
  Lists all tickets.
  """
  def list_tickets do
    Repo.all(Ticket)
  end

  @doc """
  Paginates tickets.
  """
  def paginate_tickets(page, page_size) do
    from(t in Ticket,
      order_by: [desc: t.inserted_at],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
    |> Enum.map(&deserialize_seats/1)
  end

  @doc """
  Counts tickets per passenger phone for the given phone numbers.
  Returns a map of `%{phone => count}`.
  """
  def counts_by_passenger_phones(phones) when is_list(phones) do
    phones = phones |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if phones == [] do
      %{}
    else
      from(t in Ticket,
        where: t.passenger_phone in ^phones,
        group_by: t.passenger_phone,
        select: {t.passenger_phone, count(t.id)}
      )
      |> Repo.all()
      |> Map.new()
    end
  end

  @doc """
  Counts total tickets.
  """
  def count_tickets do
    Repo.aggregate(Ticket, :count, :id)
  end

  @doc """
  Gets a single ticket by ticket_id.
  """
  def get_ticket!(ticket_id), do: Repo.get_by!(Ticket, ticket_id: ticket_id) |> deserialize_seats

  @doc """
  Gets a single ticket by ticket_id, returns nil if not found.
  """
  def get_ticket(ticket_id) do
    from(t in Ticket, where: fragment("LOWER(?) = LOWER(?)", t.ticket_id, ^ticket_id))
    |> Repo.one()
    |> Repo.preload(bus: [:bus_operator])
    |> deserialize_seats()
  end

  @doc """
  Searches tickets by ticket_id or passenger details.
  """
  def search_tickets(query) when is_binary(query) and byte_size(query) > 0 do
    pattern = "%#{query}%"

    from(t in Ticket,
      where:
        fragment("LOWER(?) LIKE LOWER(?)", t.ticket_id, ^pattern) or
          fragment("LOWER(?) LIKE LOWER(?)", t.passenger_name, ^pattern) or
          fragment("LOWER(?) LIKE LOWER(?)", t.passenger_phone, ^pattern)
    )
    |> Repo.all()
    |> Enum.map(&deserialize_seats/1)
  end

  def search_tickets(_), do: []

  @doc """
  Creates a ticket.
  """
  def create_ticket(attrs) do
    # ... logic ...
    attrs =
      for {k, v} <- attrs, into: %{} do
        {to_string(k), v}
      end
      |> serialize_seats()

    case %Ticket{}
         |> Ticket.changeset(attrs)
         |> Repo.insert() do
      {:ok, ticket} = result ->
        _ = Xpressbus.AdminAlerts.booking_created(ticket)
        result

      other ->
        other
    end
  end

  @doc """
  Updates a ticket.
  """
  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
  end

  defp serialize_seats(attrs) when is_map(attrs) do
    # Handle both string and atom keys for "seats"
    seats = Map.get(attrs, "seats") || Map.get(attrs, :seats)

    cond do
      is_list(seats) ->
        encoded = Jason.encode!(seats)

        if Map.has_key?(attrs, "seats") or not Enum.any?(Map.keys(attrs), &is_atom/1) do
          # Use string key and ensure no mixed keys if possible (though cast will fail anyway if mixed)
          attrs |> Map.delete(:seats) |> Map.put("seats", encoded)
        else
          # Use atom key
          attrs |> Map.delete("seats") |> Map.put(:seats, encoded)
        end

      true ->
        attrs
    end
  end

  def deserialize_seats(%{seats: nil} = ticket), do: ticket

  def deserialize_seats(%{seats: seats} = ticket) when is_binary(seats) do
    case Jason.decode(seats) do
      {:ok, decoded} -> %{ticket | seats: decoded}
      _ -> ticket
    end
  end

  def deserialize_seats(ticket), do: ticket
end
