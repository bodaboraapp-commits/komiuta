defmodule Xpressbus.Trending do
  @moduledoc """
  Read-only trending-route data for the "recent bookings" pills on the landing
  page.

  The pills are deliberately privacy-safe: only the route (`from`/`to`), the
  number of bookings and the time of the latest booking are exposed. No
  passenger, phone number, ticket id or price is ever selected.

  Data source: `tickets` with `status = "confirmed"`.

    * **Live mode** - routes with confirmed bookings in the last 7 days,
      ordered by booking count, then recency.
    * **Popular mode** - fallback when there are no bookings in the live
      window: the all-time most booked routes (still ordered by count).
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  @live_window_hours 24 * 7
  @default_limit 8

  @type pill :: %{
          from: String.t(),
          to: String.t(),
          count: pos_integer(),
          relative_time: String.t(),
          meta: String.t(),
          live: boolean()
        }

  @doc """
  Returns route pills for the landing page, newest/trending first.

  Options:

    * `:limit` - maximum number of pills (default #{@default_limit}).
  """
  @spec recent_booking_pills(keyword()) :: [pill()]
  def recent_booking_pills(opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    case grouped_routes(limit, :live) do
      [] -> grouped_routes(limit, :popular)
      live -> live
    end
  end

  @doc """
  Human readable age of a booking, e.g. `"just now"`, `"4m ago"`, `"3h ago"`,
  `"2d ago"`.
  """
  @spec relative_time(NaiveDateTime.t() | DateTime.t()) :: String.t()
  def relative_time(%DateTime{} = value), do: value |> DateTime.to_naive() |> relative_time()

  def relative_time(%NaiveDateTime{} = value) do
    seconds = max(NaiveDateTime.diff(NaiveDateTime.utc_now(), value), 0)

    cond do
      seconds < 60 -> "just now"
      seconds < 3_600 -> "#{div(seconds, 60)}m ago"
      seconds < 86_400 -> "#{div(seconds, 3_600)}h ago"
      true -> "#{div(seconds, 86_400)}d ago"
    end
  end

  # --- Queries ---------------------------------------------------------------

  defp grouped_routes(limit, mode) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    base =
      from(t in Ticket,
        where:
          t.status == "confirmed" and
            not is_nil(t.from) and t.from != "" and
            not is_nil(t.to) and t.to != ""
      )

    query =
      case mode do
        :live ->
          since = NaiveDateTime.add(now, -@live_window_hours * 3_600)

          from(t in base,
            where: t.inserted_at >= ^since,
            group_by: [t.from, t.to],
            select: %{
              from: t.from,
              to: t.to,
              count: count(t.id),
              last_booked_at: max(t.inserted_at)
            },
            order_by: [desc: count(t.id), desc: max(t.inserted_at)],
            limit: ^limit
          )

        :popular ->
          from(t in base,
            group_by: [t.from, t.to],
            select: %{
              from: t.from,
              to: t.to,
              count: count(t.id),
              last_booked_at: max(t.inserted_at)
            },
            order_by: [desc: count(t.id), desc: max(t.inserted_at)],
            limit: ^limit
          )
      end

    Enum.map(Repo.all(query), &to_pill(&1, mode))
  end

  defp to_pill(route, mode) do
    relative_time = relative_time(route.last_booked_at)

    %{
      from: titleize(route.from),
      to: titleize(route.to),
      count: route.count,
      relative_time: relative_time,
      meta: if(mode == :live, do: relative_time, else: "#{route.count} booked"),
      live: mode == :live
    }
  end

  defp titleize(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
