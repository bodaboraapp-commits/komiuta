defmodule Xpressbus.GooglePlaces do
  @moduledoc """
  Fetch top-rated hotels, stays and restaurants from Google Maps Platform.

  The builder asks for real recommendations ranked by Google user ratings rather
  than hard-coded cards. Credentials come from the Google Maps integration saved
  on the admin Integration page, so operators can replace or restrict the key
  without a code change.

  Calls are cached in ETS for a few hours because Places API usage is billed.
  Every public function degrades to `{:error, reason}` instead of raising, so the
  itinerary page can fall back to curated content when the key is missing or a
  specific Google API is not enabled for the project.
  """

  require Logger

  @endpoint "https://places.googleapis.com/v1/places:searchText"
  @cache :xpressbus_google_places_cache
  @cache_ttl :timer.hours(6)
  @field_mask "places.displayName,places.formattedAddress,places.rating,places.userRatingCount,places.googleMapsUri,places.photos"
  @fallback_images [
    "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1559339352-11d035aa65de?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1559314809-0d155014e29e?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=600&q=80",
    "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=600&q=80"
  ]

  @doc """
  Returns up to `limit` places ranked by Google rating and review volume.

  `category` is `:hotels` or `:restaurants`. Each result is a display-ready map:

      %{name, address, rating, reviews, image, maps_url}
  """
  def recommendations(city, category, limit \\ 8)

  def recommendations(city, category, limit) when not is_binary(city) or city == "" do
    _ = category
    _ = limit
    {:error, :missing_destination}
  end

  def recommendations(city, category, limit) when category in [:hotels, :restaurants] do
    cache_key = {category, String.downcase(city)}

    cached(cache_key, fn -> fetch_recommendations(city, category, limit) end)
  end

  def recommendations(_city, _category, _limit), do: {:error, :unsupported_category}

  @doc """
  A Google Static Maps image URL for the destination, or nil when the integration
  is not configured. Static Maps is used instead of the JS SDK so the itinerary
  page stays server-rendered and works without a browser key prompt.
  """
  def static_map(city) do
    with key when is_binary(key) and key != "" <- api_key() do
      query = URI.encode_www_form(city)

      "https://maps.googleapis.com/maps/api/staticmap?center=#{query}&zoom=12" <>
        "&size=640x640&scale=2&maptype=roadmap" <>
        "&markers=color:0xFF4C00%7C#{query}&key=#{key}"
    else
      _ -> nil
    end
  end

  @doc "A Google Maps search URL for hotels or restaurants in the destination."
  def search_url(city, category) do
    query =
      case category do
        :hotels -> "best hotels and accommodation in #{city}"
        :restaurants -> "best restaurants in #{city}"
      end

    "https://www.google.com/maps/search/?api=1&query=" <> URI.encode_www_form(query)
  end

  defp fetch_recommendations(city, category, limit) do
    with key when is_binary(key) and key != "" <- api_key(),
         {:ok, body} <- search_text(key, query(city, category)) do
      places = body |> Map.get("places", []) |> Enum.map(&parse_place(&1, key))

      places =
        places
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(&score/1, :desc)
        |> Enum.take(limit)

      if places == [] do
        {:error, :no_results}
      else
        {:ok, places}
      end
    else
      {:error, :not_configured} = error -> error
      nil -> {:error, :not_configured}
      {:error, reason} -> {:error, reason}
      _other -> {:error, :unexpected_response}
    end
  end

  defp query(city, :hotels), do: "best hotels and accommodation in #{city}"
  defp query(city, :restaurants), do: "best restaurants in #{city}"

  defp search_text(key, text_query) do
    request = [
      json: %{textQuery: text_query, maxResultCount: 10, languageCode: "en"},
      headers: [{"X-Goog-Api-Key", key}, {"X-Goog-FieldMask", @field_mask}],
      receive_timeout: 3_500,
      retry: false
    ]

    case Req.post(@endpoint, request) do
      {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
        {:ok, body}

      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        case Jason.decode(body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, :invalid_json}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("Google Places request failed with HTTP #{status}: #{inspect(body)}")
        {:error, {:http_status, status}}

      {:error, reason} ->
        Logger.warning("Google Places request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_place(place, key) when is_map(place) do
    name = get_in(place, ["displayName", "text"])

    if is_binary(name) and name != "" do
      %{
        name: name,
        address: place["formattedAddress"] || "",
        rating: normalize_rating(place["rating"]),
        reviews: place["userRatingCount"] || 0,
        image: photo_url(place, key),
        maps_url:
          place["googleMapsUri"] ||
            "https://www.google.com/maps/search/?api=1&query=#{URI.encode_www_form(name)}"
      }
    end
  end

  defp parse_place(_place, _key), do: nil

  defp normalize_rating(nil), do: nil
  defp normalize_rating(rating) when is_number(rating), do: Float.round(rating / 1, 1)
  defp normalize_rating(_rating), do: nil

  defp photo_url(%{"photos" => [%{"name" => name} | _]}, key) when is_binary(name) do
    "https://places.googleapis.com/v1/#{name}/media?maxWidthPx=600&key=#{key}"
  end

  defp photo_url(_place, _key), do: nil

  defp score(%{rating: nil, reviews: reviews}), do: reviews

  defp score(%{rating: rating, reviews: reviews}),
    do: rating * 1000 + :math.log10(reviews + 1) * 10

  defp api_key do
    if Application.get_env(:xpressbus, :google_places_enabled, true) do
      Xpressbus.Integrations.google_maps_api_key()
    end
  rescue
    _error -> nil
  end

  defp cached(key, fun) do
    now = System.monotonic_time(:millisecond)
    cache_key = {@cache, key}

    case :persistent_term.get(cache_key, nil) do
      {value, inserted_at} when now - inserted_at < @cache_ttl ->
        value

      _other ->
        value = fun.()
        :persistent_term.put(cache_key, {value, now})
        value
    end
  end

  @doc false
  def fallback_image(index), do: Enum.at(@fallback_images, rem(index, length(@fallback_images)))
end
