defmodule Xpressbus.ChyllzAccount do
  @moduledoc """
  Read-only view model for the Chyllz account view in the user dashboard
  ("My Chyllz" tab, also reachable at `/dashboard?tab=chyllz`).

  The page is deliberately honest about the data Komiuta keeps today:

    * **trips** come from the traveller's tickets — the only booking history the
      platform stores — matched by phone number exactly like the dashboard;
    * **stories** come from the curated travel blog (`XpressbusWeb.Blog`);
    * **destinations** come from the curated city pages (`XpressbusWeb.Cities`),
      so the sidebar is always populated before the Chyllz catalogue is seeded.

  Nothing here writes to the database and every query is bounded.
  """

  import Ecto.Query

  alias Xpressbus.Chyllz
  alias Xpressbus.HotelBookings
  alias Xpressbus.Repo
  alias Xpressbus.Tickets
  alias Xpressbus.Tickets.Ticket
  alias XpressbusWeb.Blog
  alias XpressbusWeb.Cities

  @recent_trip_limit 3
  @destination_limit 6
  @pick_limit 3
  @story_preview_limit 3

  # Most popular first: the order travellers actually search for.
  @destination_order ~w(mombasa nairobi kisumu eldoret nakuru kitale)

  @doc """
  Returns everything the account page needs in one map.

  Options:

    * `:recent_trips` - how many trip cards to return (default #{@recent_trip_limit})

  The result has:

    * `:stats` - `:trips`, `:upcoming` and `:places_visited` counts
    * `:recent_trips` - trip-card maps, newest first
    * `:default_city` - the city to show weather for
    * `:next_trip` - the next upcoming trip card (or `nil`)
    * `:destinations` - popular destination chips
    * `:stories` - number of published travel stories
    * `:picks` - Chyllz catalogue suggestions, only for accounts without trips
      (keeps the page useful and balanced instead of leaving a bare column)
  """
  def overview(user, opts \\ []) do
    limit = Keyword.get(opts, :recent_trips, @recent_trip_limit)
    trips = recent_trips(user, limit)
    hotel_bookings = HotelBookings.list_for_user(user.id)

    %{
      stats: stats(user) |> Map.put(:stays, length(hotel_bookings)),
      recent_trips: trips,
      hotel_bookings: hotel_bookings,
      default_city: default_city(trips, hotel_bookings),
      next_trip: Enum.find(trips, &(&1.status_key in [:ongoing, :upcoming])),
      destinations: destinations(),
      stories: story_count(),
      picks: if(trips == [] and hotel_bookings == [], do: picks(), else: []),
      story_cards: if(trips == [] and hotel_bookings == [], do: story_cards(), else: [])
    }
  end

  @doc """
  A few published travel stories (from the curated blog) used to keep the
  account page balanced and useful for travellers without trip history yet.
  """
  def story_cards(limit \\ @story_preview_limit) do
    limit = limit |> to_int(@story_preview_limit) |> min(6)

    Blog.all()
    |> Enum.take(limit)
    |> Enum.map(fn post ->
      %{
        id: "chyllz-story-" <> to_string(post.slug),
        title: post.title,
        category: post.category,
        read_minutes: post.read_minutes,
        href: "/blog/" <> to_string(post.slug)
      }
    end)
  end

  @doc """
  Suggests a few real Chyllz catalogue entries for travellers with no booking
  history yet. Prefers stays, then hidden gems, then upcoming events.

  Each pick is a display-ready map: `:id`, `:kind`, `:icon`, `:title`,
  `:location`, `:meta` and `:href`.
  """
  def picks(limit \\ @pick_limit) do
    limit = limit |> to_int(@pick_limit) |> min(6)

    case Chyllz.hotels(limit: limit) do
      [] ->
        case Chyllz.hidden_gems(limit: limit) do
          [] -> Chyllz.upcoming_events(limit: limit) |> Enum.map(&event_pick/1)
          gems -> Enum.map(gems, &gem_pick/1)
        end

      hotels ->
        Enum.map(hotels, &hotel_pick/1)
    end
  end

  defp hotel_pick(hotel) do
    %{
      id: "chyllz-pick-hotel-" <> to_string(hotel.id),
      kind: "Stay",
      icon: :bag,
      title: blank_to(hotel.name, "Chyllz stay"),
      location: blank_to(hotel.location, "East Africa"),
      meta: format_money(hotel.price_per_night) <> "/night",
      href: "/tour-packages/hotels?q=" <> URI.encode_www_form(to_string(hotel.name))
    }
  end

  defp gem_pick(gem) do
    %{
      id: "chyllz-pick-gem-" <> to_string(gem.id),
      kind: "Hidden gem",
      icon: :map,
      title: blank_to(gem.title, "Hidden gem"),
      location: blank_to(gem.location, "East Africa"),
      meta: "Explore",
      href: "/our-packages/hidden-gems?q=" <> URI.encode_www_form(to_string(gem.title))
    }
  end

  defp event_pick(event) do
    %{
      id: "chyllz-pick-event-" <> to_string(event.id),
      kind: "Event",
      icon: :calendar,
      title: blank_to(event.title, "Chyllz event"),
      location: blank_to(event.location, "East Africa"),
      meta: format_short_date(event.date),
      href: "/tour-packages/events?q=" <> URI.encode_www_form(to_string(event.title))
    }
  end

  defp format_short_date(%Date{} = date), do: Calendar.strftime(date, "%d %b")
  defp format_short_date(_date), do: "Explore"

  @doc """
  Counts the traveller's trips, upcoming trips and distinct places visited.

  A cancelled ticket never counts as an upcoming trip or a place visited.
  """
  def stats(user) do
    today = Date.utc_today()

    case identity(user) do
      nil ->
        %{trips: 0, upcoming: 0, places_visited: 0}

      phone ->
        base = base_query(phone)

        upcoming =
          from(t in base,
            where: t.travel_date >= ^today and t.status != "cancelled",
            select: count(t.id)
          )
          |> Repo.one()

        visited =
          from(t in base,
            where: t.travel_date < ^today and t.status != "cancelled" and not is_nil(t.to),
            distinct: true,
            select: t.to
          )
          |> Repo.all()
          |> Enum.reject(&(&1 in [nil, ""]))
          |> length()

        %{
          trips: Repo.aggregate(base, :count, :id),
          upcoming: upcoming || 0,
          places_visited: visited
        }
    end
  end

  @doc """
  Returns up to `limit` trip cards for the traveller, newest travel date first.

  Each card is a display-ready map (:id, :title, :company, :location,
  :status, :status_key, :travel_date, :departure, :fare, :art, :href).
  """
  def recent_trips(user, limit \\ @recent_trip_limit) do
    limit = limit |> to_int(@recent_trip_limit) |> min(12)

    case identity(user) do
      nil ->
        []

      phone ->
        from(t in base_query(phone),
          order_by: [desc: t.travel_date, desc: t.inserted_at],
          limit: ^limit
        )
        |> Repo.all()
        |> Enum.map(&Tickets.deserialize_seats/1)
        |> Enum.map(&trip_summary/1)
    end
  end

  @doc """
  Returns the popular destination chips used in the sidebar.

  Always returns real, linkable destinations: the curated city pages, ordered by
  how often travellers book them.
  """
  def destinations do
    cities = Cities.all()

    @destination_order
    |> Enum.map(fn slug -> {slug, Map.get(cities, slug)} end)
    |> Enum.reject(fn {_slug, city} -> is_nil(city) end)
    |> Enum.take(@destination_limit)
    |> Enum.map(fn {slug, city} ->
      %{
        slug: slug,
        name: city.name,
        region: city.region,
        search_url: "/tour-packages/hotels?q=" <> URI.encode_www_form(city.name)
      }
    end)
  end

  @doc """
  Number of travel stories published on the Komiuta blog.
  """
  def story_count do
    Blog.all()
    |> length()
  end

  # ------------------------------------------------------------------ queries

  defp base_query(phone) do
    from(t in Ticket, where: t.passenger_phone == ^phone or t.passenger_name == ^phone)
  end

  defp identity(%{phone: phone}) when is_binary(phone) and phone != "", do: phone
  defp identity(_user), do: nil

  defp default_city([%{to: to} | _rest]) when is_binary(to) and to != "", do: to
  defp default_city([%{from: from} | _rest]) when is_binary(from) and from != "", do: from
  defp default_city(_trips), do: "Nairobi"

  defp default_city([], [%{hotel_location: location} | _rest])
       when is_binary(location) and location != "",
       do: location

  defp default_city(trips, _bookings), do: default_city(trips)

  # --------------------------------------------------------------- trip card

  defp trip_summary(ticket) do
    {status, status_key} = trip_status(ticket)

    %{
      id: ticket.ticket_id,
      title: trip_title(ticket),
      from: ticket.from,
      to: ticket.to,
      company: blank_to(ticket.company, "Bus trip"),
      location: blank_to(title_case(ticket.to), "—"),
      status: status,
      status_key: status_key,
      travel_date: format_date(ticket.travel_date),
      departure: format_departure(ticket),
      fare: format_money(ticket.price),
      seats: format_seats(ticket.seats),
      art: art_variant(ticket),
      href: "/dashboard"
    }
  end

  defp trip_title(ticket) do
    from = title_case(ticket.from)
    to = title_case(ticket.to)

    cond do
      from == "" and to == "" -> "Bus trip"
      to == "" -> from
      from == "" -> to
      true -> "#{from} → #{to}"
    end
  end

  defp trip_status(ticket) do
    today = Date.utc_today()

    cond do
      ticket.status == "cancelled" ->
        {"Cancelled", :cancelled}

      ticket.status in ["pending", "failed"] ->
        {"Pending", :pending}

      is_nil(ticket.travel_date) ->
        {"Completed", :completed}

      ticket.travel_date == today ->
        {"Ongoing", :ongoing}

      Date.compare(ticket.travel_date, today) == :gt ->
        {"Upcoming", :upcoming}

      true ->
        {"Completed", :completed}
    end
  end

  defp art_variant(ticket) do
    key = "#{ticket.from}:#{ticket.to}"

    case :erlang.phash2(key, 3) do
      0 -> :mountains
      1 -> :coast
      _other -> :savanna
    end
  end

  defp format_date(nil), do: "—"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d %b, %Y")
  defp format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b, %Y")
  defp format_date(value) when is_binary(value), do: value
  defp format_date(_value), do: "—"

  defp format_departure(%{departure: nil, arrival: nil}), do: "—"
  defp format_departure(%{departure: nil, arrival: arrival}), do: arrival
  defp format_departure(%{departure: departure, arrival: nil}), do: departure

  defp format_departure(%{departure: departure, arrival: arrival}) do
    "#{departure} – #{arrival}"
  end

  defp format_seats(nil), do: "—"

  defp format_seats(seats) when is_list(seats) do
    if seats == [], do: "—", else: Enum.join(seats, ", ")
  end

  defp format_seats(seats) when is_binary(seats) do
    case Jason.decode(seats) do
      {:ok, list} when is_list(list) ->
        if list == [], do: "—", else: Enum.join(list, ", ")

      _other ->
        seats
    end
  end

  defp format_seats(_seats), do: "—"

  defp blank_to(value, fallback) do
    case value do
      nil -> fallback
      "" -> fallback
      value -> value
    end
  end

  @doc """
  Formats a ticket price for display, e.g. `"KSH 2300"` or `"1500"` becomes
  `"Ksh 2,300"`. Unparseable values are returned unchanged.
  """
  def format_money(nil), do: "—"

  def format_money(value) do
    text = value |> to_string() |> String.trim()

    case Regex.run(~r/(\d[\d,]*)(?:\.\d+)?/, text) do
      [_match, digits] ->
        amount =
          digits
          |> String.replace(",", "")
          |> String.to_integer()

        if amount > 0, do: "Ksh " <> group_digits(amount), else: text

      _no_number ->
        text
    end
  end

  defp group_digits(amount) do
    amount
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp title_case(nil), do: ""

  defp title_case(value) do
    value
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp to_int(value, _default) when is_integer(value), do: max(value, 0)
  defp to_int(_value, default), do: default
end
