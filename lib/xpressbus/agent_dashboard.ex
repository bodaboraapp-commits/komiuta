defmodule Xpressbus.AgentDashboard do
  @moduledoc """
  Read-only dashboard data for the KOMIUTA Agent PWA.

  An agent is attached to a bus operator (the "partner" they represent). All
  numbers and bookings here are scoped to the buses belonging to that operator,
  so an agent only ever sees their partner's business.
  """

  import Ecto.Query

  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.Bookings.Bus
  alias Xpressbus.BusOperators.BusOperator
  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  @recent_limit 8
  @chart_days 7

  @doc """
  Returns the dashboard assigns for an agent application:

      %{
        operator: %BusOperator{} | nil,
        kpis: %{...},
        recent_bookings: [...],
        chart: [...],
        routes: [...]
      }
  """
  def load(%AgentApplication{} = agent) do
    operator = operator_for(agent)
    base = bookings_query(operator, agent)
    confirmed = where(base, [t], t.status == "confirmed")
    today = local_date()

    kpis = %{
      total_bookings: count(base),
      confirmed: count(confirmed),
      cancelled: count(where(base, [t], t.status == "cancelled")),
      pending: count(where(base, [t], t.status == "pending")),
      upcoming: count(where(confirmed, [t], t.travel_date >= ^today)),
      today: count(where(confirmed, [t], t.travel_date == ^today)),
      sales_total: sales_total(confirmed),
      routes: routes_count(confirmed),
      next_departure: next_departure(confirmed, today)
    }

    chart = bookings_chart(base)

    %{
      operator: operator,
      kpis: kpis,
      recent_bookings: recent_bookings(base),
      chart: chart,
      chart_max: chart |> Enum.map(& &1.bookings) |> Enum.max(fn -> 0 end),
      routes: recent_routes(confirmed),
      scope_label: scope_label(agent)
    }
  end

  @doc """
  All partner bookings the agent is allowed to see, newest first.

  Admins can restrict an agent to one from/to route; otherwise this returns the
  full platform booking history for the agent's partner operator.
  """
  def bookings(%AgentApplication{} = agent) do
    agent
    |> then(&bookings_query(operator_for(&1), &1))
    |> order_by([t], desc: t.inserted_at)
    |> limit(500)
    |> select_booking_fields()
    |> Repo.all()
    |> format_bookings()
  end

  @doc "Human label describing the booking scope set by the admin."
  def scope_label(%AgentApplication{booking_scope: "route"} = agent) do
    case {agent.booking_from, agent.booking_to} do
      {from, to} when is_binary(from) and is_binary(to) and from != "" and to != "" ->
        "Route: #{from} → #{to}"

      _ ->
        "All partner bookings"
    end
  end

  def scope_label(%AgentApplication{}), do: "All partner bookings"

  @doc "The bus operator (partner) an agent represents, if any."
  def operator_for(%AgentApplication{bus_operator: %BusOperator{} = operator}), do: operator

  def operator_for(%AgentApplication{bus_operator_id: nil}), do: nil

  def operator_for(%AgentApplication{bus_operator_id: operator_id}) do
    Repo.get(BusOperator, operator_id)
  end

  @doc "Human friendly booking status label."
  def status_label("confirmed"), do: "Confirmed"
  def status_label("pending"), do: "Pending"
  def status_label("cancelled"), do: "Cancelled"
  def status_label(other) when is_binary(other), do: String.capitalize(other)
  def status_label(_other), do: "Unknown"

  @doc "Formats a ticket price such as `\"KSH 1,800\"` as an integer amount."
  def amount(%Ticket{price: price}), do: amount(price)

  def amount(price) when is_binary(price) do
    case Regex.run(~r/\d[\d,]*/, price) do
      [digits] -> digits |> String.replace(",", "") |> String.to_integer()
      _ -> 0
    end
  end

  def amount(_price), do: 0

  @doc "Formats an integer amount as `\"KES 1,800\"`."
  def money(nil), do: "KES 0"

  def money(amount) when is_integer(amount) do
    "KES " <> format_number(amount)
  end

  defp format_number(number) do
    number
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp bookings_query(nil, _agent), do: from(t in Ticket, where: false)

  defp bookings_query(%BusOperator{id: operator_id}, %AgentApplication{} = agent) do
    from(t in Ticket,
      join: b in Bus,
      on: b.id == t.bus_id,
      where: b.bus_operator_id == ^operator_id
    )
    |> apply_booking_scope(agent)
  end

  defp apply_booking_scope(query, %AgentApplication{booking_scope: "route"} = agent) do
    from_value = normalise_route(agent.booking_from)
    to_value = normalise_route(agent.booking_to)

    if from_value && to_value do
      where(
        query,
        [t],
        fragment("LOWER(TRIM(?)) = ?", t.from, ^from_value) and
          fragment("LOWER(TRIM(?)) = ?", t.to, ^to_value)
      )
    else
      query
    end
  end

  defp apply_booking_scope(query, _agent), do: query

  defp normalise_route(nil), do: nil

  defp normalise_route(value),
    do: value |> to_string() |> String.trim() |> String.downcase() |> blank_to_nil()

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp count(query), do: Repo.aggregate(query, :count, :id)

  defp sales_total(query) do
    query
    |> select(
      [t],
      sum(fragment("CAST(REGEXP_REPLACE(?, '[^0-9]', '') AS UNSIGNED)", t.price))
    )
    |> Repo.one()
    |> case do
      nil -> 0
      total -> total |> to_string() |> String.to_integer()
    end
  rescue
    _ -> 0
  end

  defp routes_count(query) do
    query
    |> distinct(true)
    |> select([t], {t.from, t.to})
    |> Repo.all()
    |> length()
  end

  defp next_departure(query, today) do
    query
    |> where([t], t.travel_date >= ^today)
    |> order_by([t], asc: t.travel_date, asc: t.departure)
    |> limit(1)
    |> select([t], %{
      from: t.from,
      to: t.to,
      travel_date: t.travel_date,
      departure: t.departure,
      company: t.company
    })
    |> Repo.one()
  end

  defp recent_bookings(query) do
    query
    |> order_by([t], desc: t.inserted_at)
    |> limit(@recent_limit)
    |> select_booking_fields()
    |> Repo.all()
    |> format_bookings()
  end

  defp select_booking_fields(query) do
    select(query, [t], %{
      id: t.id,
      ticket_id: t.ticket_id,
      passenger_name: t.passenger_name,
      passenger_phone: t.passenger_phone,
      from: t.from,
      to: t.to,
      travel_date: t.travel_date,
      departure: t.departure,
      price: t.price,
      status: t.status,
      company: t.company,
      inserted_at: t.inserted_at
    })
  end

  defp format_bookings(bookings) do
    Enum.map(bookings, fn booking ->
      Map.merge(booking, %{
        amount: amount(booking.price),
        amount_label: money(amount(booking.price)),
        status_label: status_label(booking.status),
        travel_label:
          if(booking.travel_date,
            do: Calendar.strftime(booking.travel_date, "%d %b %Y"),
            else: "-"
          ),
        booked_label:
          if(booking.inserted_at,
            do: Calendar.strftime(booking.inserted_at, "%d %b, %H:%M"),
            else: "-"
          )
      })
    end)
  end

  defp recent_routes(query) do
    query
    |> group_by([t], [t.from, t.to])
    |> order_by([t], desc: count(t.id))
    |> limit(5)
    |> select([t], %{from: t.from, to: t.to, bookings: count(t.id)})
    |> Repo.all()
  end

  defp bookings_chart(query) do
    since = DateTime.utc_now() |> DateTime.add(-(@chart_days - 1) * 86_400, :second)

    counts =
      query
      |> where([t], t.inserted_at >= ^since)
      |> group_by([t], fragment("DATE(?)", t.inserted_at))
      |> select([t], {fragment("DATE(?)", t.inserted_at), count(t.id)})
      |> Repo.all()
      |> Map.new(fn {date, total} -> {to_string(date), total} end)

    today = local_date()

    for offset <- (@chart_days - 1)..0//-1 do
      date = Date.add(today, -offset)

      %{
        date: date,
        label: Calendar.strftime(date, "%a"),
        bookings: Map.get(counts, to_string(date), 0)
      }
    end
  end

  @doc "Kenya local date (EAT, UTC+3)."
  def local_date do
    DateTime.utc_now()
    |> DateTime.add(3 * 3600, :second)
    |> DateTime.to_date()
  end
end
