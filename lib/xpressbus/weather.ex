defmodule Xpressbus.Weather do
  @moduledoc """
  Current conditions and a short forecast for the Chyllz account landing page.

  By default the data comes from [Open-Meteo](https://open-meteo.com), a free,
  keyless weather API, so no configuration or secret is required. Admins can
  connect a [WeatherAPI.com](https://www.weatherapi.com) key under
  **Admin → Settings → Integrations → WeatherAPI**; when that integration is
  active and has an API key, WeatherAPI provides the data for Chyllz instead.
  If a WeatherAPI request fails (bad key, quota, outage), the lookup transparently
  falls back to Open-Meteo so the widget keeps working.

  Two endpoints are used:

    * the geocoding endpoint turns the city a traveller types into coordinates;
    * the forecast endpoint returns current conditions plus hourly temperatures
      and a daily summary.

  Success is always a plain map of display-ready values, so the LiveView never
  has to understand provider payloads. Failure is an atom such as `:timeout` or
  `:not_found`; the page renders a friendly fallback with a retry button instead
  of crashing or showing fake weather.

  Every successful lookup is cached in `:persistent_term` for
  `:weather, :cache_ttl_seconds` (15 minutes by default). Errors are never
  cached, so a retry always reaches the network again. The cache is keyed by
  provider, coordinates and API key, and the geocoded city name is cached
  separately, which keeps a page refresh free of network calls.

  ## Testing

  Two application settings make the module deterministic in tests:

    * `config :xpressbus, :weather, enabled: false` skips every network call and
      returns `{:error, :disabled}` from `load/1`;
    * `config :xpressbus, :weather_forecast_override` accepts either a ready
      forecast map or a one-argument function, and is returned before any other
      check. This is how tests render the full weather widget.

  `parse_forecast/2` and `parse_weatherapi_forecast/2` are public so provider
  payloads can be parsed in tests without touching the network.
  """

  alias Xpressbus.Integrations

  @geocode_url "https://geocoding-api.open-meteo.com/v1/search"
  @forecast_url "https://api.open-meteo.com/v1/forecast"
  @weatherapi_base "https://api.weatherapi.com/v1"

  @default_timeout 5_000
  @default_cache_ttl 900
  @max_query_length 60
  @hourly_points 7
  @daily_points 3

  @default_location %{
    name: "Nairobi",
    country: "Kenya",
    latitude: -1.2921,
    longitude: 36.8219
  }

  # WMO weather interpretation codes, grouped into the glyphs the UI draws.
  @conditions %{
    0 => {"Clear sky", :clear},
    1 => {"Mainly clear", :clear},
    2 => {"Partly cloudy", :partly_cloudy},
    3 => {"Overcast", :cloud},
    45 => {"Foggy", :fog},
    48 => {"Freezing fog", :fog},
    51 => {"Light drizzle", :rain},
    53 => {"Drizzle", :rain},
    55 => {"Heavy drizzle", :rain},
    56 => {"Freezing drizzle", :rain},
    57 => {"Freezing drizzle", :rain},
    61 => {"Light rain", :rain},
    63 => {"Rain", :rain},
    65 => {"Heavy rain", :rain},
    66 => {"Freezing rain", :rain},
    67 => {"Freezing rain", :rain},
    71 => {"Light snow", :snow},
    73 => {"Snow", :snow},
    75 => {"Heavy snow", :snow},
    77 => {"Snow grains", :snow},
    80 => {"Light showers", :rain},
    81 => {"Showers", :rain},
    82 => {"Heavy showers", :rain},
    85 => {"Snow showers", :snow},
    86 => {"Heavy snow showers", :snow},
    95 => {"Thunderstorm", :storm},
    96 => {"Thunderstorm with hail", :storm},
    99 => {"Thunderstorm with hail", :storm}
  }

  @doc """
  The fallback location used when the traveller has no booking history yet.
  """
  def default_location, do: @default_location

  @doc """
  Whether live weather lookups are allowed by configuration.
  """
  def enabled? do
    :xpressbus
    |> Application.get_env(:weather, [])
    |> Keyword.get(:enabled, true)
  end

  @doc """
  Loads the weather for a city name, a geocoded location map, or `nil` for the
  default location.

  Accepts a map with atom keys (`:latitude`/`:longitude`) or string keys, so it
  can be called with the map returned by the geocoder internally or passed in
  from tests.

  Returns `{:ok, forecast}` or `{:error, reason}` where `reason` is one of
  `:disabled`, `:empty_query`, `:invalid_location`, `:not_found`, `:timeout`,
  `:request_failed`, `:invalid_response` or `{:http_status, status}`.
  """
  def load(query \\ nil) do
    case forecast_override() do
      nil ->
        do_load(query)

      fun when is_function(fun, 1) ->
        fun.(query)

      forecast when is_map(forecast) ->
        {:ok, forecast}
    end
  end

  @doc """
  The active weather provider: `:weatherapi` when an active WeatherAPI
  integration with a key is configured, otherwise the keyless `:open_meteo`
  fallback.
  """
  def provider do
    if weatherapi_config(), do: :weatherapi, else: :open_meteo
  end

  @doc """
  The stored WeatherAPI integration config (`%{api_key: key}`), or `nil` when the
  integration is missing, disabled or has no key.

  The key is captured in the admin **Settings → Integrations → WeatherAPI** tab.
  """
  def weatherapi_config do
    case Integrations.get_config_by_provider("weather_api") do
      %{active: true, config: config} when is_map(config) ->
        key = Map.get(config, "api_key") || Map.get(config, :api_key)

        if is_binary(key) and String.trim(key) != "" do
          %{api_key: String.trim(key)}
        end

      _other ->
        nil
    end
  rescue
    _error -> nil
  catch
    _kind, _reason -> nil
  end

  defp do_load(nil), do: fetch_for_location(@default_location)

  defp do_load(%{} = location), do: fetch_for_location(normalize_location(location))

  defp do_load(query) when is_binary(query) do
    query = normalize_query(query)

    if query == "" do
      {:error, :empty_query}
    else
      provider = provider()

      with :ok <- ensure_enabled(),
           {:ok, location} <- geocode(query, provider) do
        fetch_for_location(location, provider)
      end
    end
  end

  defp do_load(_query), do: {:error, :invalid_location}

  defp fetch_for_location(location, provider \\ nil) do
    location = normalize_location(location)
    provider = provider || provider()

    if is_number(location.latitude) and is_number(location.longitude) do
      with :ok <- ensure_enabled() do
        cached(
          {:forecast, cache_provider_tag(provider), Float.round(location.latitude * 1.0, 2),
           Float.round(location.longitude * 1.0, 2)},
          fn ->
            request_provider_forecast(provider, location)
          end
        )
      end
    else
      {:error, :invalid_location}
    end
  end

  defp ensure_enabled do
    if enabled?(), do: :ok, else: {:error, :disabled}
  end

  defp cache_provider_tag(:weatherapi) do
    case weatherapi_config() do
      %{api_key: key} ->
        digest =
          :sha256
          |> :crypto.hash(key)
          |> Base.encode16(case: :lower)
          |> binary_part(0, 8)

        {:weatherapi, digest}

      nil ->
        :open_meteo
    end
  end

  defp cache_provider_tag(_provider), do: :open_meteo

  # ---------------------------------------------------------------- geocoding

  defp geocode(query, provider) do
    cached({:geocode, cache_provider_tag(provider), String.downcase(query)}, fn ->
      request_geocode(query, provider)
    end)
  end

  defp request_geocode(query, :weatherapi) do
    case request_weatherapi_geocode(query) do
      {:ok, _location} = ok -> ok
      {:error, _reason} -> request_geocode(query, :open_meteo)
    end
  end

  defp request_geocode(query, _provider) do
    params = [name: query, count: 1, language: "en", format: "json"]

    case get(@geocode_url, params) do
      {:ok, %{"results" => [result | _]}} when is_map(result) ->
        {:ok,
         %{
           name: to_string(result["name"] || query),
           country: to_string(result["country"] || result["admin1"] || ""),
           latitude: result["latitude"],
           longitude: result["longitude"],
           timezone: result["timezone"]
         }}

      {:ok, _payload} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request_weatherapi_geocode(query) do
    case weatherapi_config() do
      nil ->
        {:error, :not_configured}

      %{api_key: key} ->
        case get_json("#{@weatherapi_base}/search.json", key: key, q: query) do
          {:ok, [result | _]} when is_map(result) ->
            {:ok,
             %{
               name: to_string(result["name"] || query),
               country: to_string(result["country"] || result["region"] || ""),
               latitude: result["lat"],
               longitude: result["lon"],
               timezone: result["tz_id"]
             }}

          {:ok, _payload} ->
            {:error, :not_found}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # ---------------------------------------------------------------- forecast

  defp request_provider_forecast(:weatherapi, location) do
    case request_weatherapi_forecast(location) do
      {:ok, _forecast} = ok -> ok
      {:error, _reason} -> request_provider_forecast(:open_meteo, location)
    end
  end

  defp request_provider_forecast(:open_meteo, location) do
    params = [
      latitude: location.latitude,
      longitude: location.longitude,
      current:
        "temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,is_day",
      hourly: "temperature_2m",
      daily: "weather_code,temperature_2m_max,temperature_2m_min",
      timezone: "auto",
      forecast_days: @daily_points
    ]

    case get(@forecast_url, params) do
      {:ok, payload} ->
        {:ok, parse_forecast(location, payload)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request_weatherapi_forecast(location) do
    case weatherapi_config() do
      nil ->
        {:error, :not_configured}

      %{api_key: key} ->
        params = [
          key: key,
          q: "#{location.latitude},#{location.longitude}",
          days: @daily_points,
          aqi: "no",
          alerts: "no"
        ]

        case get_json("#{@weatherapi_base}/forecast.json", params) do
          {:ok, payload} -> {:ok, parse_weatherapi_forecast(location, payload)}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Turns an Open-Meteo forecast payload into display-ready values.

  Public for tests; production code always calls `load/1`.

  The returned map has `:location`, `:temperature`, `:feels_like`, `:condition`,
  `:icon`, `:is_day`, `:high`, `:low`, `:humidity`, `:wind`, `:hourly`,
  `:daily`, `:timezone` and `:fetched_at`.
  """
  def parse_forecast(location, payload) when is_map(payload) do
    location = normalize_location(location)
    current = map_or_empty(payload["current"])
    hourly = map_or_empty(payload["hourly"])
    daily = map_or_empty(payload["daily"])

    {condition, icon} = condition_for(current["weather_code"])
    daily_max = List.wrap(daily["temperature_2m_max"])
    daily_min = List.wrap(daily["temperature_2m_min"])

    %{
      location: %{name: location.name, country: location.country},
      temperature: round_temp(current["temperature_2m"]),
      feels_like: round_temp(current["apparent_temperature"]),
      condition: condition,
      icon: icon,
      is_day: day?(current["is_day"]),
      high: round_temp(Enum.at(daily_max, 0)),
      low: round_temp(Enum.at(daily_min, 0)),
      humidity: round_temp(current["relative_humidity_2m"]),
      wind: round_temp(current["wind_speed_10m"]),
      hourly:
        build_hourly(
          List.wrap(hourly["time"]),
          List.wrap(hourly["temperature_2m"]),
          current["time"]
        ),
      daily: build_daily(daily),
      timezone: payload["timezone"],
      fetched_at: DateTime.utc_now()
    }
  end

  @doc """
  Turns a WeatherAPI.com forecast payload into display-ready values.

  Public for tests; production code always calls `load/1`. The map has the same
  shape as `parse_forecast/2` so the Chyllz widget does not care which provider
  answered.
  """
  def parse_weatherapi_forecast(location, payload) when is_map(payload) do
    location = normalize_location(location)
    location_payload = map_or_empty(payload["location"])
    current = map_or_empty(payload["current"])
    days = payload |> get_in(["forecast", "forecastday"]) |> List.wrap()
    today = days |> List.first() |> map_or_empty()
    today_day = map_or_empty(today["day"])
    {condition, icon} = weatherapi_condition(current["condition"])

    hours =
      days
      |> Enum.flat_map(fn day -> List.wrap(map_or_empty(day)["hour"]) end)
      |> Enum.filter(&is_map/1)

    %{
      location: %{
        name: location_payload["name"] || location.name,
        country: location_payload["country"] || location.country
      },
      temperature: round_temp(current["temp_c"]),
      feels_like: round_temp(current["feelslike_c"]),
      condition: condition,
      icon: icon,
      is_day: day?(current["is_day"]),
      high: round_temp(today_day["maxtemp_c"]),
      low: round_temp(today_day["mintemp_c"]),
      humidity: round_temp(current["humidity"]),
      wind: round_temp(current["wind_kph"]),
      hourly:
        build_hourly(
          Enum.map(hours, & &1["time"]),
          Enum.map(hours, & &1["temp_c"]),
          current["last_updated"]
        ),
      daily: build_weatherapi_daily(days),
      timezone: location_payload["tz_id"],
      fetched_at: DateTime.utc_now()
    }
  end

  @doc """
  Maps a WeatherAPI.com condition map (`%{"code" => code, "text" => text}`) to
  `{label, glyph}`. Missing or unknown values fall back to a neutral cloud.
  """
  def weatherapi_condition(condition) when is_map(condition) do
    text = condition["text"]
    code = condition["code"]
    {to_string(text || "Cloudy"), weatherapi_icon(code, text)}
  end

  def weatherapi_condition(_condition), do: {"Cloudy", :cloud}

  defp build_weatherapi_daily(days) do
    days
    |> Enum.take(@daily_points)
    |> Enum.with_index()
    |> Enum.map(fn {day, index} ->
      day = map_or_empty(day)
      summary = map_or_empty(day["day"])
      {condition, icon} = weatherapi_condition(summary["condition"])

      %{
        date: day["date"],
        label: day_label(day["date"], index),
        condition: condition,
        icon: icon,
        high: round_temp(summary["maxtemp_c"]),
        low: round_temp(summary["mintemp_c"])
      }
    end)
  end

  defp weatherapi_icon(code, _text) when is_integer(code) do
    cond do
      code == 1087 or code in 1273..1282 -> :storm
      code in [1066, 1069, 1072, 1114, 1117] -> :snow
      code in 1204..1237 -> :snow
      code in 1249..1264 -> :snow
      code in [1063] or code in 1150..1201 -> :rain
      code in 1240..1246 -> :rain
      code in [1012, 1015, 1018, 1021, 1024, 1030, 1135, 1147] -> :fog
      code == 1000 -> :clear
      code == 1003 -> :partly_cloudy
      true -> :cloud
    end
  end

  defp weatherapi_icon(_code, text) do
    text = text |> to_string() |> String.downcase()

    cond do
      String.contains?(text, ["thunder", "storm"]) -> :storm
      String.contains?(text, ["snow", "sleet", "ice", "blizzard", "freezing"]) -> :snow
      String.contains?(text, ["rain", "drizzle", "shower"]) -> :rain
      String.contains?(text, ["fog", "mist", "haze"]) -> :fog
      String.contains?(text, ["sunny", "clear"]) -> :clear
      String.contains?(text, ["partly"]) -> :partly_cloudy
      true -> :cloud
    end
  end

  @doc """
  Maps a WMO weather code to `{label, glyph}`.

  Unknown or missing codes fall back to a neutral "Cloudy" cloud glyph.
  """
  def condition_for(code) when is_integer(code) do
    Map.get(@conditions, code, {"Cloudy", :cloud})
  end

  def condition_for(_code), do: {"Cloudy", :cloud}

  defp build_hourly(times, temps, now_iso) do
    entries =
      times
      |> Enum.zip(temps)
      |> Enum.filter(fn {time, temp} -> is_binary(time) and is_number(temp) end)

    upcoming =
      if is_binary(now_iso) do
        # Compare whole hours ("2026-11-10T09") so the current hour is included
        # even though the provider reports minutes on `current.time`.
        current_hour = String.slice(now_iso, 0, 13)
        Enum.filter(entries, fn {time, _temp} -> String.slice(time, 0, 13) >= current_hour end)
      else
        []
      end

    if(upcoming == [], do: entries, else: upcoming)
    |> Enum.take(@hourly_points)
    |> Enum.map(fn {time, temp} ->
      %{time: time, label: hour_label(time), temperature: round_temp(temp)}
    end)
  end

  defp build_daily(daily) do
    times = List.wrap(daily["time"])
    codes = List.wrap(daily["weather_code"])
    maxes = List.wrap(daily["temperature_2m_max"])
    mins = List.wrap(daily["temperature_2m_min"])

    times
    |> Enum.with_index()
    |> Enum.take(@daily_points)
    |> Enum.map(fn {time, index} ->
      {condition, icon} = condition_for(Enum.at(codes, index))

      %{
        date: time,
        label: day_label(time, index),
        condition: condition,
        icon: icon,
        high: round_temp(Enum.at(maxes, index)),
        low: round_temp(Enum.at(mins, index))
      }
    end)
  end

  defp hour_label(time) when is_binary(time) do
    time = String.replace(time, " ", "T")

    case String.split(time, "T", parts: 2) do
      [_date, clock] when byte_size(clock) >= 5 -> String.slice(clock, 0, 5)
      _other -> time
    end
  end

  defp hour_label(time), do: to_string(time)

  defp day_label(_time, 0), do: "Today"

  defp day_label(time, _index) do
    with true <- is_binary(time),
         {:ok, date} <- Date.from_iso8601(String.slice(time, 0, 10)) do
      Calendar.strftime(date, "%a")
    else
      _other -> "—"
    end
  end

  # ------------------------------------------------------------------- helpers

  defp get(url, params) do
    case get_json(url, params) do
      {:ok, %{} = payload} -> {:ok, payload}
      {:ok, _payload} -> {:error, :invalid_response}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_json(url, params) do
    request =
      Req.new(
        url: url,
        params: params,
        retry: false,
        receive_timeout: timeout(),
        connect_options: [timeout: min(timeout(), 3_000)]
      )

    case Req.get(request) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case decode_body(body) do
          nil -> {:error, :invalid_response}
          decoded -> {:ok, decoded}
        end

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, %{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %{reason: :connect_timeout}} ->
        {:error, :timeout}

      {:error, _reason} ->
        {:error, :request_failed}
    end
  rescue
    _error -> {:error, :request_failed}
  catch
    :exit, _reason -> {:error, :request_failed}
  end

  defp decode_body(body) when is_map(body), do: body
  defp decode_body(body) when is_list(body), do: body

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _other -> nil
    end
  end

  defp decode_body(_body), do: nil

  defp cached(key, fun) do
    now = System.monotonic_time(:second)

    case :persistent_term.get({__MODULE__, key}, nil) do
      {expires_at, value} when is_integer(expires_at) ->
        if now < expires_at do
          {:ok, value}
        else
          fetch_and_cache(key, fun, now)
        end

      _missing ->
        fetch_and_cache(key, fun, now)
    end
  end

  defp fetch_and_cache(key, fun, now) do
    case fun.() do
      {:ok, value} ->
        :persistent_term.put({__MODULE__, key}, {now + cache_ttl(), value})
        {:ok, value}

      error ->
        error
    end
  end

  @doc false
  # Clears this module's cached lookups. Used by tests; harmless in production.
  def clear_cache do
    :persistent_term.get()
    |> Enum.each(fn
      {{__MODULE__, _key} = key, _value} -> :persistent_term.erase(key)
      _other -> :ok
    end)

    :ok
  end

  defp forecast_override do
    Application.get_env(:xpressbus, :weather_forecast_override)
  end

  defp normalize_query(query) do
    query
    |> to_string()
    |> String.replace(~r/[\r\n\t]/, " ")
    |> String.trim()
    |> String.slice(0, @max_query_length)
  end

  defp normalize_location(location) when is_map(location) do
    %{
      name: location[:name] || location["name"] || "Nairobi",
      country: location[:country] || location["country"] || "Kenya",
      latitude: location[:latitude] || location["latitude"],
      longitude: location[:longitude] || location["longitude"]
    }
  end

  defp normalize_location(_location), do: @default_location

  defp map_or_empty(value) when is_map(value), do: value
  defp map_or_empty(_value), do: %{}

  defp day?(true), do: true
  defp day?(1), do: true
  defp day?(_value), do: false

  defp round_temp(value) when is_number(value), do: round(value)
  defp round_temp(_value), do: nil

  defp timeout do
    :xpressbus
    |> Application.get_env(:weather, [])
    |> Keyword.get(:http_timeout_ms, @default_timeout)
  end

  defp cache_ttl do
    :xpressbus
    |> Application.get_env(:weather, [])
    |> Keyword.get(:cache_ttl_seconds, @default_cache_ttl)
  end
end
