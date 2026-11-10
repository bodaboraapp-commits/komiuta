defmodule Xpressbus.Places do
  @moduledoc """
  Real-world destination lookup for the Chyllz AI trip builder.

  The destination step used to accept any free text as a "place". This module
  turns that input into a verified place:

    1. **Geocoding** — the query is sent to Open-Meteo's public geocoding API
       (the same provider the weather widget uses). It returns real cities and
       towns with coordinates, country and region, which is what types ahead
       while the traveller types.
    2. **AI interpretation** — when the geocoder has no match (landmarks,
       regions, natural-language requests such as "warm beaches in Asia"), the
       configured Chyllz AI model is asked to map the request to real places.
       Each suggestion is then checked back against the geocoder, so a place is
       only offered when it can be resolved to real coordinates.

  Results are cached in `:persistent_term` for an hour; HTTP failures never
  raise and are returned as `{:error, reason}`. Tests can inject results through
  `config :xpressbus, :places_search_override` (see the module tests), which
  keeps the suite fully offline.
  """

  alias Xpressbus.AI

  @geocode_url "https://geocoding-api.open-meteo.com/v1/search"
  @limit 8
  @ai_place_limit 4
  @min_query_length 2
  @max_query_length 80
  @cache_ttl_ms 60 * 60 * 1000
  @http_timeout_ms 4_000

  @ai_system_prompt """
  You resolve travel requests to real places on Earth.
  Reply with ONLY a JSON array (no prose, no markdown) of up to 4 objects in the
  form [{"name": "City or place", "country": "Country"}].
  Use only real, existing places. Never invent a place. When the request names a
  region, landmark or travel style, map it to the nearest well-known city or
  town a traveller could actually visit.
  """

  @type place :: %{
          required(:name) => String.t(),
          required(:country) => String.t(),
          required(:label) => String.t(),
          optional(:region) => String.t() | nil,
          optional(:latitude) => number() | nil,
          optional(:longitude) => number() | nil,
          optional(:timezone) => String.t() | nil,
          optional(:population) => integer() | nil,
          optional(:source) => :geocoding | :ai | :curated
        }

  @doc """
  Type-ahead search for real places matching `query`.

  Returns `{:ok, places}` (possibly an empty list) or `{:error, reason}`.
  Queries shorter than two characters never hit the network.
  """
  @spec search(String.t(), keyword()) :: {:ok, [place()]} | {:error, term()}
  def search(query, opts \\ []) do
    query = normalize_query(query)

    cond do
      String.length(query) < @min_query_length ->
        {:ok, []}

      override = Application.get_env(:xpressbus, :places_search_override) ->
        {:ok, override_results(override, query)}

      true ->
        cached({:search, String.downcase(query)}, fn -> request_geocode(query, opts) end)
    end
  end

  @doc """
  Resolves a free-text destination into a single verified place.

  Uses the geocoder first and falls back to the configured AI model for
  landmarks or natural-language requests. Returns
  `{:ok, place, all_matching_places}` or `{:error, reason}`.
  """
  @spec resolve(String.t(), keyword()) :: {:ok, place(), [place()]} | {:error, term()}
  def resolve(query, opts \\ []) do
    query = normalize_query(query)

    cond do
      String.length(query) < @min_query_length ->
        {:error, :not_found}

      true ->
        case search(query, opts) do
          {:ok, [first | _] = results} -> {:ok, first, results}
          {:ok, []} -> ai_resolve(query, opts)
          {:error, _reason} = error -> error
        end
    end
  end

  @doc false
  # Clears the in-memory cache. Used by tests (and available for operations).
  def reset_cache do
    for {key, _value} <- :persistent_term.get() do
      case key do
        {__MODULE__, _} -> :persistent_term.erase(key)
        _other -> :ok
      end
    end

    :ok
  end

  @doc """
  Returns a display label for a place, e.g. `"Paris, Île-de-France, France"`.
  """
  def label(%{name: name} = place) do
    [name, Map.get(place, :region), Map.get(place, :country)]
    |> Enum.reject(&blank?/1)
    |> Enum.uniq()
    |> Enum.join(", ")
  end

  # ------------------------------------------------------------------ AI fallback

  defp ai_resolve(query, opts) do
    if AI.configured?() do
      with {:ok, places} <- ai_places(query, opts),
           true <- places != [] do
        results =
          places
          |> Enum.flat_map(fn place -> geocode_ai_place(place, opts) end)
          |> Enum.uniq_by(&{&1.name, &1.country})
          |> Enum.take(@ai_place_limit)

        case results do
          [] -> {:error, :not_found}
          [first | _] = results -> {:ok, first, results}
        end
      else
        _other -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

  defp ai_places(query, opts) do
    messages = [
      %{"role" => "system", "content" => @ai_system_prompt},
      %{"role" => "user", "content" => query}
    ]

    options = [
      max_tokens: 300,
      temperature: 0.1,
      timeout: 8_000,
      req_options: Keyword.get(opts, :req_options, [])
    ]

    case AI.chat(messages, options) do
      {:ok, text} -> {:ok, parse_ai_places(text)}
      {:error, _reason} -> {:error, :ai_failed}
    end
  end

  defp parse_ai_places(text) when is_binary(text) do
    text
    |> extract_json_array()
    |> Jason.decode()
    |> case do
      {:ok, list} when is_list(list) ->
        list
        |> Enum.flat_map(&normalize_ai_place/1)
        |> Enum.uniq_by(&{&1.name, &1.country})
        |> Enum.take(@ai_place_limit)

      _other ->
        []
    end
  end

  defp parse_ai_places(_text), do: []

  defp extract_json_array(text) do
    case Regex.run(~r/\[.*\]/s, text) do
      [json | _rest] -> json
      nil -> "[]"
    end
  end

  defp normalize_ai_place(%{} = place) do
    name = text(Map.get(place, "name") || Map.get(place, :name))
    country = text(Map.get(place, "country") || Map.get(place, :country))

    if name == "" do
      []
    else
      [
        %{
          name: name,
          country: country,
          region: nil,
          latitude: nil,
          longitude: nil,
          source: :ai
        }
      ]
    end
  end

  defp normalize_ai_place(_place), do: []

  # AI suggestions are only offered once they resolve to real coordinates.
  defp geocode_ai_place(%{name: name, country: country}, opts) do
    case request_geocode(name, opts) do
      {:ok, []} ->
        []

      {:ok, results} ->
        best = best_country_match(results, country)

        [
          best
          |> Map.put(:source, :ai)
          |> Map.put(:label, label(best))
        ]

      {:error, _reason} ->
        []
    end
  end

  defp best_country_match(results, country) do
    if blank?(country) do
      List.first(results)
    else
      Enum.find(results, &countries_match?(&1.country, country)) || List.first(results)
    end
  end

  defp countries_match?(left, right) do
    left = String.downcase(text(left))
    right = String.downcase(text(right))

    left != "" and right != "" and
      (String.contains?(left, right) or String.contains?(right, left))
  end

  # ------------------------------------------------------------------- geocoding

  defp request_geocode(query, opts) do
    params = [name: query, count: @limit, language: "en", format: "json"]

    request_options =
      [
        params: params,
        receive_timeout: Keyword.get(opts, :timeout, @http_timeout_ms),
        connect_options: [timeout: 3_000],
        retry: false
      ]
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.get(@geocode_url, request_options) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, parse_geocode(body)}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, exception} ->
        {:error, {:request_failed, exception}}
    end
  rescue
    exception ->
      {:error, {:client_failed, exception}}
  end

  defp parse_geocode(%{"results" => results}) when is_list(results) do
    results
    |> Enum.flat_map(&normalize_geocode_result/1)
    |> Enum.uniq_by(&{&1.name, &1.country})
    |> Enum.take(@limit)
  end

  defp parse_geocode(_body), do: []

  defp normalize_geocode_result(%{"name" => name} = result)
       when is_binary(name) and name != "" do
    name = String.trim(name)
    country = text(result["country"])
    region = blank_to_nil(text(result["admin1"]))

    [
      %{
        name: name,
        country: country,
        region: region,
        label: label(%{name: name, region: region, country: country}),
        latitude: result["latitude"],
        longitude: result["longitude"],
        timezone: result["timezone"],
        population: result["population"],
        source: :geocoding
      }
    ]
  end

  defp normalize_geocode_result(_result), do: []

  # --------------------------------------------------------------------- override

  defp override_results(override, query) do
    raw =
      cond do
        is_function(override, 1) -> override.(query)
        is_list(override) -> override
        true -> []
      end

    raw
    |> Enum.flat_map(&normalize_override/1)
    |> Enum.take(@limit)
  end

  defp normalize_override(%{} = place) do
    name = text(Map.get(place, :name) || Map.get(place, "name"))

    if name == "" do
      []
    else
      country = text(Map.get(place, :country) || Map.get(place, "country"))
      region = blank_to_nil(text(Map.get(place, :region) || Map.get(place, "region")))

      [
        %{
          name: name,
          country: country,
          region: region,
          label: label(%{name: name, region: region, country: country}),
          latitude: Map.get(place, :latitude) || Map.get(place, "latitude"),
          longitude: Map.get(place, :longitude) || Map.get(place, "longitude"),
          timezone: Map.get(place, :timezone) || Map.get(place, "timezone"),
          population: Map.get(place, :population) || Map.get(place, "population"),
          source: :geocoding
        }
      ]
    end
  end

  defp normalize_override(_place), do: []

  # ------------------------------------------------------------------------ utils

  defp cached(key, fun) do
    now = System.monotonic_time(:millisecond)

    case :persistent_term.get({__MODULE__, key}, nil) do
      {value, expires_at} when is_integer(expires_at) and expires_at > now ->
        value

      _other ->
        value = fun.()
        :persistent_term.put({__MODULE__, key}, {value, now + @cache_ttl_ms})
        value
    end
  end

  defp normalize_query(query) do
    query
    |> to_string()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> String.slice(0, @max_query_length)
  end

  defp text(nil), do: ""
  defp text(value) when is_binary(value), do: String.trim(value)
  defp text(value) when is_number(value), do: to_string(value)
  defp text(_value), do: ""

  defp blank?(value), do: text(value) == ""

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_value), do: nil
end
