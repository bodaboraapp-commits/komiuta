defmodule Xpressbus.Bookings.Scraper do
  @moduledoc """
  Fetches real intercity schedules from BuuPass' marketplace stream endpoint and
  stores them locally.

  History: this module used to generate hard-coded fallback buses (8 operators x
  a fixed schedule) whenever BuuPass returned no data. Those fabricated rows made
  KOMIUTA show far more buses than BuuPass. The fallback has been removed; real
  schedules are used, and legacy fallback rows are marked `source =
  "legacy_fallback"` so public search ignores them.
  """

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Bookings.{DepartureWindow, Search}
  alias Xpressbus.BusOperators
  alias Xpressbus.BusOperators.BusOperator
  alias Xpressbus.Repo
  import Ecto.Query
  require Logger

  @api_url "https://marketplace-v2.buupass.com/marketplace/buses/stream-schedules"
  # Public client token shipped in BuuPass' own browser bundle. It is not a
  # user secret; requests use it exactly as buupass.com does.
  @api_token "66Shf2aP.owT6xw6QKSWNO9EeQIIlz20JM3nNHul3"

  @doc """
  Returns live buses for a route/date. Real BuuPass schedules are fetched first
  and persisted; if the API is unavailable the last real cached rows are used.

  The cached rows are read through `Xpressbus.Bookings.Search.list_bookable/4`,
  so the live path and the database path share the exact same visibility and
  2-hour departure-window rules.
  """
  def search(from, to, date, _return_date \\ nil) do
    if Application.get_env(:xpressbus, :scraper_enabled, true) do
      search_live(from, to, date)
    else
      Search.list_bookable(from, to, date)
    end
  end

  defp search_live(from, to, date) do
    case fetch_schedules(from, to, date) do
      {:ok, []} ->
        Logger.info("No BuuPass schedules for #{from} -> #{to} on #{date}; using cache.")
        Search.list_bookable(from, to, date)

      {:ok, buses} ->
        Logger.info("Fetched #{length(buses)} BuuPass schedules for #{from} -> #{to} on #{date}.")

        save_buses_to_db(buses)
        Search.list_bookable(from, to, date)

      {:error, reason} ->
        Logger.warning("BuuPass schedule fetch failed for #{from} -> #{to}: #{inspect(reason)}")
        Search.list_bookable(from, to, date)
    end
  end

  @doc false
  # Backwards-compatible helper. The visibility rule lives in
  # `Xpressbus.Bookings.DepartureWindow`; this delegates so the booking search
  # and the scraper can never disagree. `now` is UTC for tests.
  def filter_soon_departures(buses, now_utc \\ DateTime.utc_now()) do
    now_eat =
      now_utc
      |> DateTime.add(3 * 60 * 60, :second)
      |> DateTime.to_naive()
      |> NaiveDateTime.truncate(:second)

    cutoff =
      NaiveDateTime.add(
        now_eat,
        DepartureWindow.min_lead_time_hours() * 3_600,
        :second
      )

    # Each bus is judged against its own travel date (future dates are always
    # outside the window; same-day buses departing soon are hidden).
    Enum.filter(buses, fn bus ->
      case departure_date(bus) do
        %Date{} = date -> DepartureWindow.bookable?(bus, date, cutoff)
        nil -> false
      end
    end)
  end

  defp departure_date(bus) do
    value = Map.get(bus, :travel_date) || Map.get(bus, "travel_date")

    case Date.from_iso8601(to_string(value)) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  @doc false
  def fetch_schedules(from, to, date) do
    with {:ok, date_obj} <- Date.from_iso8601(to_string(date)) do
      query =
        URI.encode_query(%{
          "leaving_from" => from,
          "going_to" => to,
          "departing_on" => Calendar.strftime(date_obj, "%d/%m/%Y"),
          "token" => @api_token
        })

      url = @api_url <> "?" <> query

      case Req.get(url,
             headers: [
               {"user-agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"},
               {"accept", "text/event-stream, application/json"},
               {"origin", "https://buupass.com"},
               {"referer", "https://buupass.com/"}
             ],
             receive_timeout: 30_000,
             retry: :transient
           ) do
        {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
          buses =
            body
            |> parse_stream(from, to, date_obj)
            |> Enum.uniq_by(&{&1.company, &1.departure, &1.arrival, &1.registration})

          {:ok, buses}

        {:ok, %Req.Response{status: status}} ->
          {:error, {:http, status}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      _ -> {:error, :invalid_date}
    end
  end

  @doc false
  def parse_stream(body, from, to, %Date{} = date) do
    body
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      line = String.trim(line)

      with "data:" <> payload <- line,
           {:ok, decoded} <- Jason.decode(String.trim(payload)),
           buses when is_list(buses) <- decoded["data"] do
        Enum.flat_map(buses, fn item ->
          case build_bus(item, from, to, date) do
            nil -> []
            %Bus{seats: "0 seats left"} -> []
            bus -> [bus]
          end
        end)
      else
        _ -> []
      end
    end)
  end

  def parse_stream(_body, _from, _to, _date), do: []

  defp build_bus(item, from, to, date) when is_map(item) do
    operator = get_in(item, ["operator", "name"]) || item["operator_name"] || item["operator"]

    if is_binary(operator) do
      departure = item["departure_time"]
      arrival = item["arrival_time"]
      arrival_label = if format_time(arrival) == "", do: "Direct", else: format_time(arrival)
      seat_types = item["seats_types"] || []
      normal_fare = seat_fare(seat_types, ["normal"]) || min_seat_fare(seat_types) || item["fare"]
      vip_fare = seat_fare(seat_types, ["vip"])
      business_fare = seat_fare(seat_types, ["business"])
      first_fare = seat_fare(seat_types, ["first class", "first_class", "first"])
      seats = item["number_of_available_seats"]
      currency = seat_currency(seat_types) || "KES"

      %Bus{
        company: operator,
        departure: format_time(departure),
        arrival: arrival_label,
        seats: if(is_integer(seats), do: "#{seats} seats left", else: "Seats available"),
        price: format_money(normal_fare, currency),
        registration: registration_for(item),
        occupied_seats: [],
        total_seats: item["bus_capacity"] || 44,
        amenities: [],
        rating: nil,
        vip_price: format_money(vip_fare, currency),
        business_price: format_money(business_fare, currency),
        first_class_price: format_money(first_fare, currency) || "",
        duration: duration_label(departure, arrival),
        seat_types: seat_type_names(seat_types),
        from: from,
        to: to,
        travel_date: date,
        logo_url: get_in(item, ["operator", "logo"]),
        source: "buupass_api"
      }
    end
  end

  defp build_bus(_item, _from, _to, _date), do: nil

  defp seat_fare(seat_types, aliases) do
    Enum.find_value(seat_types, fn seat ->
      name = seat["alias"] || seat["name"]

      if is_binary(name) and String.downcase(name) in aliases do
        seat["fare"]
      end
    end)
  end

  defp min_seat_fare(seat_types) do
    seat_types
    |> Enum.map(fn seat -> seat["fare"] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
  end

  defp seat_currency(seat_types) do
    Enum.find_value(seat_types, fn seat -> seat["currency"] end)
  end

  defp seat_type_names(seat_types) do
    names =
      seat_types
      |> Enum.map(fn seat -> seat["name"] || seat["alias"] end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if names == [], do: ["Normal"], else: names
  end

  defp registration_for(item) do
    reference = item["trip_id"] || item["route_schedule_id"] || item["id"] || "unknown"
    "BUU-" <> to_string(reference)
  end

  defp format_money(nil, _currency), do: nil

  defp format_money(fare, currency) when is_number(fare) and fare > 0 do
    "#{currency} #{round(fare)}"
  end

  defp format_money(_fare, _currency), do: nil

  defp format_time(nil), do: ""

  defp format_time(value) do
    value = to_string(value)

    case Time.from_iso8601(value) do
      {:ok, time} ->
        suffix = if time.hour < 12, do: "AM", else: "PM"
        hour = time.hour |> rem(12) |> then(&if(&1 == 0, do: 12, else: &1))
        "#{hour}:#{String.pad_leading(to_string(time.minute), 2, "0")} #{suffix}"

      _ ->
        value
    end
  end

  defp duration_label(departure, arrival) do
    dep = time_minutes(departure)
    arr = time_minutes(arrival)

    if is_integer(dep) and is_integer(arr) do
      diff = if arr <= dep, do: arr + 24 * 60 - dep, else: arr - dep
      "#{div(diff, 60)}h #{rem(diff, 60)}m"
    else
      "Direct"
    end
  end

  defp time_minutes(value) do
    case Time.from_iso8601(to_string(value)) do
      {:ok, time} -> time.hour * 60 + time.minute
      _ -> nil
    end
  end

  defp save_buses_to_db(buses) do
    from_city = List.first(buses).from
    to_city = List.first(buses).to
    travel_date = List.first(buses).travel_date

    existing_map =
      Repo.all(
        from(b in Bus,
          where: b.from == ^from_city and b.to == ^to_city and b.travel_date == ^travel_date
        )
      )
      |> Enum.into(%{}, fn bus -> {{bus.company, bus.registration}, bus} end)

    Enum.each(buses, fn bus_data ->
      operator = ensure_operator(bus_data.company)
      bus_data = %{bus_data | bus_operator_id: operator && operator.id}

      existing = Map.get(existing_map, {bus_data.company, bus_data.registration})
      upsert_bus_instance(bus_data, existing)
    end)
  end

  defp ensure_operator(name) do
    case Repo.get_by(BusOperator, name: name) do
      nil ->
        case BusOperators.upsert_bus_operator(%{name: name}) do
          {:ok, operator} -> operator
          _ -> nil
        end

      operator ->
        operator
    end
  end

  defp upsert_bus_instance(%Bus{} = bus_data, existing) do
    attrs = bus_data |> Map.from_struct() |> Map.delete(:id) |> Map.delete(:__meta__)

    case existing do
      nil ->
        case Repo.insert(Bus.changeset(%Bus{}, attrs)) do
          {:ok, saved} -> saved
          {:error, changeset} -> Logger.error("Could not save bus: #{inspect(changeset.errors)}")
        end

      %Bus{} = bus ->
        bus
        |> Bus.changeset(attrs)
        |> Repo.update()

      _ ->
        :ok
    end
  rescue
    error ->
      Logger.error("Could not upsert bus: #{Exception.message(error)}")
  end
end
