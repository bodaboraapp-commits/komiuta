defmodule Xpressbus.Itineraries do
  @moduledoc """
  Saved AI itineraries for the My Chyllz dashboard.

  The trip builder persists the trip brief (destination, dates, travellers,
  budget and preferences) when a traveller presses **Save**. The dashboard lists
  those briefs as cards, and the itinerary screen can be reopened from a card by
  regenerating the display itinerary from the saved brief.

  Everything here is scoped to the owning user; `list_for_user/1` and
  `get_for_user/2` never return another account's rows.
  """

  import Ecto.Query

  alias Xpressbus.Itineraries.SavedItinerary
  alias Xpressbus.{Repo, TripItinerary}

  @max_per_user 3
  @art_variants ~w(mountains coast savanna)

  @doc "Saves a trip brief for `user`, returning `{:ok, saved_itinerary}`."
  def save(%{id: user_id}, trip, itinerary) do
    %SavedItinerary{}
    |> SavedItinerary.changeset(attrs(user_id, trip, itinerary))
    |> Repo.insert()
  end

  def save(_user, _trip, _itinerary), do: {:error, :not_signed_in}

  @doc "Updates a previously saved itinerary (for example after re-opening it)."
  def update(%SavedItinerary{} = saved_itinerary, trip, itinerary) do
    saved_itinerary
    |> SavedItinerary.changeset(attrs(saved_itinerary.user_id, trip, itinerary))
    |> Repo.update()
  end

  @doc "The latest three itineraries saved by `user`, newest first."
  def list_for_user(%{id: user_id}) do
    Repo.all(
      from(saved in SavedItinerary,
        where: saved.user_id == ^user_id,
        order_by: [desc: saved.inserted_at, desc: saved.id],
        limit: @max_per_user
      )
    )
  end

  def list_for_user(_user), do: []

  @doc "Fetches one saved itinerary only when it belongs to `user`."
  def get_for_user(%{id: user_id}, id) do
    with {saved_id, ""} <- Integer.parse(to_string(id)) do
      Repo.get_by(SavedItinerary, id: saved_id, user_id: user_id)
    else
      _other -> nil
    end
  end

  def get_for_user(_user, _id), do: nil

  @doc "Rebuilds the trip brief map used by `Xpressbus.TripItinerary`."
  def to_trip(%SavedItinerary{} = saved_itinerary) do
    %{
      destination: saved_itinerary.destination,
      country: saved_itinerary.country || "",
      start_date: saved_itinerary.start_date,
      end_date: saved_itinerary.end_date,
      travel_party: saved_itinerary.travel_party,
      pets: false,
      budget: saved_itinerary.budget,
      preferences: preferences(saved_itinerary),
      latitude: saved_itinerary.latitude,
      longitude: saved_itinerary.longitude,
      place_source: saved_itinerary.source
    }
  end

  @doc "Regenerates the display itinerary for a saved brief."
  def itinerary(%SavedItinerary{} = saved_itinerary) do
    TripItinerary.generate(to_trip(saved_itinerary))
  end

  @doc "Decoded travel-preference labels for a saved itinerary."
  def preferences(%SavedItinerary{preferences: json}) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) -> Enum.filter(list, &is_binary/1)
      _other -> []
    end
  end

  def preferences(_saved_itinerary), do: []

  @doc """
  Travel status derived from the saved dates: `:upcoming`, `:ongoing` or
  `:completed`.
  """
  def status(%SavedItinerary{start_date: nil, end_date: nil}, _today), do: :upcoming

  def status(%SavedItinerary{start_date: nil, end_date: end_date}, today) do
    if Date.compare(end_date, today) == :lt, do: :completed, else: :upcoming
  end

  def status(%SavedItinerary{start_date: start_date, end_date: nil}, today) do
    if Date.compare(start_date, today) == :gt, do: :upcoming, else: :ongoing
  end

  def status(%SavedItinerary{start_date: start_date, end_date: end_date}, today) do
    cond do
      Date.compare(start_date, today) == :gt -> :upcoming
      Date.compare(end_date, today) == :lt -> :completed
      true -> :ongoing
    end
  end

  def status(%SavedItinerary{} = saved_itinerary), do: status(saved_itinerary, Date.utc_today())

  @doc "Short status chip copy, e.g. \"10 Days Left\" or \"Ends in 3 Days\"."
  def status_meta(%SavedItinerary{} = saved_itinerary, today \\ Date.utc_today()) do
    case status(saved_itinerary, today) do
      :upcoming ->
        case saved_itinerary.start_date do
          nil ->
            "Starts soon"

          start_date ->
            days = max(Date.diff(start_date, today), 0)
            if days == 0, do: "Starts today", else: "#{days} Days Left"
        end

      :ongoing ->
        case saved_itinerary.end_date do
          nil ->
            "In progress"

          end_date ->
            days = Date.diff(end_date, today)
            if days <= 0, do: "Ends today", else: "Ends in #{days} Days"
        end

      :completed ->
        Calendar.strftime(saved_itinerary.end_date, "%b %d, %Y")
    end
  end

  @doc "Trip length in days (inclusive), at least 1."
  def duration_days(%SavedItinerary{start_date: start_date, end_date: end_date})
      when not is_nil(start_date) and not is_nil(end_date) do
    max(Date.diff(end_date, start_date) + 1, 1)
  end

  def duration_days(_saved_itinerary), do: 1

  def duration_label(%SavedItinerary{} = saved_itinerary) do
    case duration_days(saved_itinerary) do
      1 -> "1 Day"
      days -> "#{days} Days"
    end
  end

  @doc "Start-date chip copy, e.g. \"20 Nov, 2026\"."
  def dates_label(%SavedItinerary{start_date: nil}), do: "Dates TBC"

  def dates_label(%SavedItinerary{start_date: start_date}) do
    Calendar.strftime(start_date, "%d %b, %Y")
  end

  @doc "Human budget label for the trip-card chip."
  def budget_label(%SavedItinerary{budget: budget}), do: budget_label(budget)

  def budget_label("cheap"), do: "Budget"
  def budget_label("balanced"), do: "Balanced"
  def budget_label("luxury"), do: "Luxury"
  def budget_label("flexible"), do: "Flexible"
  def budget_label("custom"), do: "Custom"
  def budget_label("mars"), do: "Cosmic"
  def budget_label(_budget), do: "Flexible"

  @doc "Destination plus country, e.g. \"Cox's Bazar, Bangladesh\"."
  def city_label(%SavedItinerary{} = saved_itinerary) do
    [saved_itinerary.destination, saved_itinerary.country]
    |> Enum.reject(&(is_nil(&1) or String.trim(to_string(&1)) == ""))
    |> Enum.join(", ")
  end

  @doc "Path that re-opens the saved itinerary in the trip builder."
  def path(%SavedItinerary{id: id}), do: "/trip/build-with-ai?saved=#{id}"

  @doc "Path that opens the unified itinerary management page."
  def manage_path(%SavedItinerary{id: id}), do: "/trips/saved/#{id}/manage"

  @doc "Path to share the saved itinerary on WhatsApp."
  def share_url(%SavedItinerary{title: title} = saved_itinerary) do
    path = path(saved_itinerary)
    url = "https://www.komiuta.com" <> path
    text = "#{title} - plan built with Chyllz AI: #{url}"
    "https://wa.me/?text=" <> URI.encode_www_form(text)
  end

  @doc "Cover-art variant for a trip brief; deterministic so a card never changes."
  def art_for(trip) do
    destination = to_string(Map.get(trip, :destination) || "")
    budget = to_string(Map.get(trip, :budget) || "")
    Enum.at(@art_variants, :erlang.phash2({destination, budget}, length(@art_variants)))
  end

  def art_variants, do: @art_variants

  defp attrs(user_id, trip, itinerary) do
    %{
      user_id: user_id,
      title: string_value(itinerary[:title], "A Chyllz AI escape"),
      destination: string_value(trip[:destination], "Your destination"),
      country: string_value(trip[:country]),
      start_date: trip[:start_date],
      end_date: trip[:end_date],
      travel_party: trip[:travel_party],
      budget: trip[:budget],
      preferences: Jason.encode!(List.wrap(trip[:preferences] || [])),
      art: art_for(trip),
      latitude: trip[:latitude],
      longitude: trip[:longitude],
      source: source_value(trip[:place_source])
    }
  end

  defp source_value(nil), do: nil
  defp source_value(value), do: to_string(value)

  defp string_value(value, fallback \\ "") do
    case to_string(value || "") |> String.trim() do
      "" -> fallback
      string -> string
    end
  end
end
