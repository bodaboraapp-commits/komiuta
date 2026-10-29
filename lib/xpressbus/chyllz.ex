defmodule Xpressbus.Chyllz do
  @moduledoc """
  Read-only catalogue queries that back the public Chyllz landing pages.

  The Chyllz pages (`/tour-packages` and its sub-pages) used to render
  hard-coded demo cards. They now read the same database tables the admin
  catalogue manages: `hotels`, `hidden_gems`, `car_hires` and `events`.

  Three rules are enforced here so the public site stays safe regardless of
  what is in the database:

    * only rows flagged `active` are returned — unpublished/draft catalogue
      items never leak onto the marketing pages;
    * duplicate catalogue rows are collapsed by their natural key, so a
      re-run of a data import cannot flood the page with repeated cards;
    * every query is bounded by a limit and a maximum, so a mass import can
      never make the page query unbounded data.

  Searches are simple, case-insensitive substring matches on the fields a
  traveller would reasonably type (name, location, description). SQL
  wildcards inside the user input are stripped instead of escaped, which is
  safe because the term is only ever used for display filtering.
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Bookings.{CarHire, Event, HiddenGem, Hotel}

  @default_limit 60
  @max_limit 120
  @max_search_length 80

  @doc """
  Lists active hotels, optionally filtered by a free-text search term.

  Options:

    * `:search` - free text matched against name, location and description
    * `:limit` - maximum number of hotels returned (capped at #{@max_limit})

  Results are ordered by rating (best first) and then price.
  """
  def hotels(opts \\ []) do
    limit = limit(opts)
    search = search(opts)

    from(h in Hotel,
      where: h.active == true,
      order_by: [desc: h.rating, asc: h.price_per_night, asc: h.name]
    )
    |> filter_hotels(search)
    |> Repo.all()
    |> Enum.uniq_by(& &1.name)
    |> Enum.take(limit)
  end

  @doc """
  Lists active hidden gems, optionally filtered by a free-text search term.

  Matches against title, location and description; ordered alphabetically by
  title.
  """
  def hidden_gems(opts \\ []) do
    limit = limit(opts)
    search = search(opts)

    from(g in HiddenGem, where: g.active == true, order_by: [asc: g.title])
    |> filter_hidden_gems(search)
    |> Repo.all()
    |> Enum.uniq_by(& &1.title)
    |> Enum.take(limit)
  end

  @doc """
  Lists active car hire offers, optionally filtered by a free-text search term.

  Matches against car name, vehicle type and location; ordered cheapest first.
  A car offered in two different towns is kept as two distinct offers.
  """
  def car_hires(opts \\ []) do
    limit = limit(opts)
    search = search(opts)

    from(c in CarHire,
      where: c.active == true,
      order_by: [asc: c.price_per_day, asc: c.car_name]
    )
    |> filter_car_hires(search)
    |> Repo.all()
    |> Enum.uniq_by(&{&1.car_name, &1.location})
    |> Enum.take(limit)
  end

  @doc """
  Lists upcoming active events (today or later), earliest first.

  Options:

    * `:search` - free text matched against title and location
    * `:limit` - maximum number of events returned

  Events without a date are excluded because they cannot be ordered or shown
  in the date block on the page.
  """
  def upcoming_events(opts \\ []) do
    limit = limit(opts)
    search = search(opts)

    from(e in Event,
      where: e.active == true and not is_nil(e.date) and e.date >= ^today(),
      order_by: [asc: e.date, asc: e.title]
    )
    |> filter_events(search)
    |> Repo.all()
    |> Enum.uniq_by(&{&1.title, &1.date})
    |> Enum.take(limit)
  end

  @doc """
  Lists active events that already happened, most recent first.

  The Chyllz events page uses this as a fallback so it still shows useful
  content when there are no upcoming events in the catalogue.
  """
  def past_events(opts \\ []) do
    limit = limit(opts)
    search = search(opts)

    from(e in Event,
      where: e.active == true and not is_nil(e.date) and e.date < ^today(),
      order_by: [desc: e.date, asc: e.title]
    )
    |> filter_events(search)
    |> Repo.all()
    |> Enum.uniq_by(&{&1.title, &1.date})
    |> Enum.take(limit)
  end

  @doc """
  Returns the number of distinct active catalogue entries per section.

  Used for the trust-building counters on the Chyllz overview page.
  """
  def counts do
    %{
      hotels: unique_count(from(h in Hotel, where: h.active == true, select: h.name)),
      hidden_gems: unique_count(from(g in HiddenGem, where: g.active == true, select: g.title)),
      car_hires:
        unique_count(
          from(c in CarHire, where: c.active == true, select: {c.car_name, c.location})
        ),
      events: unique_count(from(e in Event, where: e.active == true, select: {e.title, e.date}))
    }
  end

  defp unique_count(query) do
    query
    |> Repo.all()
    |> Enum.uniq()
    |> length()
  end

  defp today, do: Date.utc_today()

  defp limit(opts) do
    requested =
      case Keyword.get(opts, :limit, @default_limit) do
        value when is_integer(value) and value > 0 -> value
        _other -> @default_limit
      end

    min(requested, @max_limit)
  end

  defp search(opts) do
    opts
    |> Keyword.get(:search, "")
    |> to_string()
    |> String.replace(~r/[%_\\]/, "")
    |> String.trim()
    |> String.slice(0, @max_search_length)
  end

  defp like_term(""), do: nil
  defp like_term(term), do: "%" <> String.downcase(term) <> "%"

  defp filter_hotels(query, ""), do: query

  defp filter_hotels(query, term) do
    like = like_term(term)

    where(
      query,
      [h],
      fragment("LOWER(?) LIKE ?", h.name, ^like) or
        fragment("LOWER(?) LIKE ?", h.location, ^like) or
        fragment("LOWER(?) LIKE ?", h.description, ^like)
    )
  end

  defp filter_hidden_gems(query, ""), do: query

  defp filter_hidden_gems(query, term) do
    like = like_term(term)

    where(
      query,
      [g],
      fragment("LOWER(?) LIKE ?", g.title, ^like) or
        fragment("LOWER(?) LIKE ?", g.location, ^like) or
        fragment("LOWER(?) LIKE ?", g.description, ^like)
    )
  end

  defp filter_car_hires(query, ""), do: query

  defp filter_car_hires(query, term) do
    like = like_term(term)

    where(
      query,
      [c],
      fragment("LOWER(?) LIKE ?", c.car_name, ^like) or
        fragment("LOWER(?) LIKE ?", c.type, ^like) or
        fragment("LOWER(?) LIKE ?", c.location, ^like)
    )
  end

  defp filter_events(query, ""), do: query

  defp filter_events(query, term) do
    like = like_term(term)

    where(
      query,
      [e],
      fragment("LOWER(?) LIKE ?", e.title, ^like) or
        fragment("LOWER(?) LIKE ?", e.location, ^like) or
        fragment("LOWER(?) LIKE ?", e.description, ^like)
    )
  end
end
