defmodule Xpressbus.Bookings.HiddenGemGoogle do
  @moduledoc """
  Enriches curated hidden gems with real Google Places photos, ratings and
  coordinates.

  The gem keeps its curated category, region and access notes; Google supplies
  the presentation data. Refreshes happen through the two-day places sync, and
  misses are retried after the same window instead of on every page view.
  """

  require Logger

  alias Xpressbus.Bookings.HiddenGem
  alias Xpressbus.{GooglePlaces, Repo}

  @sync_ttl_days 2

  def enrich(gems, opts \\ [])

  def enrich([], _opts), do: []

  def enrich(gems, opts) when is_list(gems) do
    if Application.get_env(:xpressbus, :hidden_gem_google_enabled, true) do
      Enum.map(gems, &enrich_gem(&1, opts))
    else
      gems
    end
  end

  defp enrich_gem(%HiddenGem{} = gem, opts) do
    if fresh?(gem, opts), do: gem, else: sync(gem)
  end

  defp enrich_gem(gem, _opts), do: gem

  defp fresh?(gem, opts) do
    not Keyword.get(opts, :force, false) and
      match?(%DateTime{}, gem.google_synced_at) and
      DateTime.diff(DateTime.utc_now(), gem.google_synced_at, :day) < @sync_ttl_days
  end

  defp sync(%HiddenGem{} = gem) do
    case lookup(gem.title, gem.location) do
      {:ok, place} -> apply_place(gem, place)
      {:error, reason} -> mark_synced(gem, reason)
    end
  end

  defp lookup(title, location) do
    case Application.get_env(:xpressbus, :hidden_gem_google_lookup_override) do
      fun when is_function(fun, 2) -> fun.(title, location)
      _other -> GooglePlaces.lookup_place(title, location)
    end
  end

  defp apply_place(%HiddenGem{} = gem, place) when is_map(place) do
    attrs = %{
      google_place_id: Map.get(place, :id),
      google_maps_url: Map.get(place, :maps_url),
      google_photo_ref: Map.get(place, :photo_ref),
      formatted_address: Map.get(place, :address),
      review_count: Map.get(place, :reviews),
      rating: rating_decimal(Map.get(place, :rating), gem.rating),
      images: photo_images(Map.get(place, :photo_ref), gem.images),
      latitude: Map.get(place, :latitude) || gem.latitude,
      longitude: Map.get(place, :longitude) || gem.longitude,
      website_url: gem.website_url || Map.get(place, :website),
      source_url: gem.source_url || Map.get(place, :maps_url),
      google_synced_at: now()
    }

    case gem |> HiddenGem.changeset(attrs) |> Repo.update() do
      {:ok, updated} -> updated
      {:error, _changeset} -> gem
    end
  rescue
    _error -> gem
  end

  defp apply_place(gem, _place), do: gem

  defp mark_synced(%HiddenGem{} = gem, reason) do
    Logger.info("Google Places had no usable gem match for #{gem.title}: #{inspect(reason)}")

    gem
    |> HiddenGem.changeset(%{google_synced_at: now()})
    |> Repo.update()
    |> case do
      {:ok, updated} -> updated
      {:error, _changeset} -> gem
    end
  rescue
    _error -> gem
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
