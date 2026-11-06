defmodule Xpressbus.Bookings.DepartureWindow do
  @moduledoc """
  Sanitises bus search results so a trip that departs too soon to be realistic
  never appears in the search list.

  A bus is hidden when its departure on the searched service date is **less
  than 2 hours away** (Kenya time) or already in the past. Buses whose
  departure time cannot be parsed are hidden as well, because their timing
  cannot be verified.

  Departure strings are interpreted as Kenya time (EAT, UTC+3, no DST), which
  is the timezone the service dates are sold in. `:now` can be injected in
  tests as a `NaiveDateTime` in EAT.
  """

  @min_lead_time_hours 2
  @eat_offset_hours 3

  @doc "Minimum lead time, in hours, between now and a bookable departure."
  @spec min_lead_time_hours() :: pos_integer()
  def min_lead_time_hours, do: @min_lead_time_hours

  @doc """
  Keeps only buses departing at least `2` hours from `now` on `travel_date`.

  `travel_date` may be a `Date` or an ISO8601 date string. Options:

    * `:now` - a `NaiveDateTime` in EAT used as "now" (tests only).
  """
  @spec filter_bookable([map()], Date.t() | String.t(), keyword()) :: [map()]
  def filter_bookable(buses, travel_date, opts \\ [])

  def filter_bookable(buses, travel_date, opts) when is_list(buses) do
    case to_date(travel_date) do
      nil ->
        buses

      %Date{} = date ->
        now = opts |> Keyword.get_lazy(:now, &now_eat/0) |> to_naive()
        cutoff = NaiveDateTime.add(now, @min_lead_time_hours * 3_600, :second)

        Enum.filter(buses, &bookable?(&1, date, cutoff))
    end
  end

  @doc """
  True when `bus` departs on `date` at or after `cutoff` (an EAT naive datetime).

  Buses whose departure cannot be parsed are not considered bookable.
  """
  @spec bookable?(map(), Date.t(), NaiveDateTime.t()) :: boolean()
  def bookable?(bus, %Date{} = date, %NaiveDateTime{} = cutoff) do
    case departure_at(bus, date) do
      {:ok, departure} -> NaiveDateTime.compare(departure, cutoff) != :lt
      :error -> false
    end
  end

  @doc """
  Parses a departure into an EAT naive datetime on `date`.

  Supports `"7:00 AM"`, `"7:00AM"`, `"07:00"` (24h) and `"7 PM"` styles.
  """
  @spec departure_at(map(), Date.t()) :: {:ok, NaiveDateTime.t()} | :error
  def departure_at(bus, %Date{} = date) do
    with departure when is_binary(departure) <- field(bus, :departure),
         {:ok, time} <- parse_departure_time(departure) do
      {:ok, NaiveDateTime.new!(date, time)}
    else
      _ -> :error
    end
  end

  @doc """
  Parses a departure time string into a `Time`.

  Returns `:error` for blank/unrecognised values.
  """
  @spec parse_departure_time(term()) :: {:ok, Time.t()} | :error
  def parse_departure_time(departure) when is_binary(departure) do
    departure = String.trim(departure)

    cond do
      match = Regex.run(~r/^(\d{1,2}):(\d{2})\s*([AP])\.?M\.?$/i, departure) ->
        [_, hour, minute, meridiem] = match
        build_time(hour, minute, meridiem)

      match = Regex.run(~r/^(\d{1,2})\s*([AP])\.?M\.?$/i, departure) ->
        [_, hour, meridiem] = match
        build_time(hour, "0", meridiem)

      match = Regex.run(~r/^(\d{1,2}):(\d{2})(?::\d{2})?$/, departure) ->
        [_, hour, minute] = match

        with {hour, ""} <- Integer.parse(hour),
             {minute, ""} <- Integer.parse(minute),
             true <- hour in 0..23 and minute in 0..59 do
          {:ok, Time.new!(hour, minute, 0)}
        else
          _ -> :error
        end

      true ->
        :error
    end
  end

  def parse_departure_time(_departure), do: :error

  @doc "Current EAT wall-clock time as a naive datetime (UTC+3, no DST)."
  @spec now_eat() :: NaiveDateTime.t()
  def now_eat do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(@eat_offset_hours * 3_600, :second)
    |> NaiveDateTime.truncate(:second)
  end

  defp build_time(hour, minute, meridiem) do
    with {hour, ""} <- Integer.parse(hour),
         {minute, ""} <- Integer.parse(minute),
         true <- hour in 1..12 and minute in 0..59 do
      hour = rem(hour, 12)
      hour = if String.upcase(meridiem) == "P", do: hour + 12, else: hour
      {:ok, Time.new!(hour, minute, 0)}
    else
      _ -> :error
    end
  end

  defp field(bus, key) when is_map(bus),
    do: Map.get(bus, key) || Map.get(bus, Atom.to_string(key))

  defp to_date(%Date{} = date), do: date

  defp to_date(value) do
    case Date.from_iso8601(to_string(value)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp to_naive(%NaiveDateTime{} = value), do: NaiveDateTime.truncate(value, :second)

  defp to_naive(%DateTime{} = value),
    do: value |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
end
