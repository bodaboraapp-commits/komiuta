defmodule Xpressbus.Bookings.HotelGoogle do
  @moduledoc """
  Enriches curated hotel rows with real Google Places data.

  The Chyllz hotel collection stays curated (name, nightly price, description),
  but its photo, star rating, review count, formatted address and Google Maps
  link come from the Google Places API. Results are stored on the hotel row and
  refreshed at most once a week, so page views stay fast and Google is only
  billed when data is stale.

  When the Google Places integration is not configured (or a lookup cannot find
  a confident match) the hotel is left untouched and the curated fallback image
  is used. `force: true` bypasses the freshness check; tests inject
  `:hotel_google_lookup_override`.
  """

  require Logger

  alias Xpressbus.Bookings.Hotel
  alias Xpressbus.{GooglePlaces, Repo}

  @sync_ttl_days 7

  @doc "Enriches a list of `%Hotel{}` rows with Google Places data."
  def enrich(hotels, opts \\ [])

  def enrich([], _opts), do: []

  def enrich(hotels, opts) when is_list(hotels) do
    if enabled?() do
      Enum.map(hotels, &enrich_hotel(&1, opts))
    else
      hotels
    end
  end

  defp enabled? do
    Application.get_env(:xpressbus, :hotel_google_enabled, true)
  end

  defp enrich_hotel(%Hotel{} = hotel, opts) do
    if fresh?(hotel, opts) do
      hotel
    else
      sync(hotel)
    end
  end

  defp enrich_hotel(hotel, _opts), do: hotel

  defp fresh?(hotel, opts) do
    not Keyword.get(opts, :force, false) and
      match?(%DateTime{}, hotel.google_synced_at) and
      DateTime.diff(DateTime.utc_now(), hotel.google_synced_at, :day) < @sync_ttl_days
  end

  defp sync(%Hotel{} = hotel) do
    case lookup(hotel.name, hotel.location) do
      {:ok, place} -> apply_place(hotel, place)
      {:error, reason} -> mark_synced(hotel, reason)
    end
  end

  defp lookup(name, location) do
    case Application.get_env(:xpressbus, :hotel_google_lookup_override) do
      fun when is_function(fun, 2) -> fun.(name, location)
      _other -> GooglePlaces.lookup_hotel(name, location)
    end
  end

  defp apply_place(%Hotel{} = hotel, place) when is_map(place) do
    attrs = %{
      google_place_id: Map.get(place, :id),
      google_maps_url: Map.get(place, :maps_url),
      google_photo_ref: Map.get(place, :photo_ref),
      formatted_address: Map.get(place, :address),
      review_count: Map.get(place, :reviews),
      rating: rating_decimal(Map.get(place, :rating), hotel.rating),
      images: photo_images(Map.get(place, :photo_ref), hotel.images),
      google_synced_at: now()
    }

    case hotel |> Hotel.changeset(attrs) |> Repo.update() do
      {:ok, updated} -> updated
      {:error, _changeset} -> hotel
    end
  rescue
    _error -> hotel
  end

  defp apply_place(hotel, _place), do: hotel

  defp mark_synced(%Hotel{} = hotel, reason) do
    Logger.info("Google Places had no usable match for #{hotel.name}: #{inspect(reason)}")

    hotel
    |> Hotel.changeset(%{
      name: hotel.name,
      price_per_night: hotel.price_per_night,
      location: hotel.location,
      google_synced_at: now()
    })
    |> Repo.update()
    |> case do
      {:ok, updated} -> updated
      {:error, _changeset} -> hotel
    end
  rescue
    _error -> hotel
  end

  defp rating_decimal(rating, _fallback) when is_number(rating) do
    rating |> Decimal.from_float() |> Decimal.round(1)
  end

  defp rating_decimal(_rating, fallback), do: fallback

  defp photo_images(ref, _fallback) when is_binary(ref) and ref != "" do
    [GooglePlaces.photo_proxy_path(ref)]
  end

  defp photo_images(_ref, fallback), do: fallback

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
