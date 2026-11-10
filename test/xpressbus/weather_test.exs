defmodule Xpressbus.WeatherTest do
  use ExUnit.Case, async: false

  alias Xpressbus.Weather

  @payload %{
    "timezone" => "Africa/Nairobi",
    "current" => %{
      "time" => "2026-11-10T09:15",
      "temperature_2m" => 24.4,
      "relative_humidity_2m" => 51,
      "apparent_temperature" => 25.6,
      "weather_code" => 3,
      "wind_speed_10m" => 4.2,
      "is_day" => 1
    },
    "hourly" => %{
      "time" => [
        "2026-11-10T08:00",
        "2026-11-10T09:00",
        "2026-11-10T10:00",
        "2026-11-10T11:00",
        "2026-11-10T12:00",
        "2026-11-10T13:00",
        "2026-11-10T14:00",
        "2026-11-10T15:00",
        "2026-11-10T16:00",
        "2026-11-10T17:00"
      ],
      "temperature_2m" => [22.0, 23.6, 25.2, 26.8, 27.4, 28.1, 27.6, 26.2, 25.0, 24.1]
    },
    "daily" => %{
      "time" => ["2026-11-10", "2026-11-11", "2026-11-12", "2026-11-13"],
      "weather_code" => [3, 61, 0, 2],
      "temperature_2m_max" => [28.4, 27.1, 29.6, 30.2],
      "temperature_2m_min" => [17.2, 16.8, 18.0, 18.4]
    }
  }

  @weatherapi_payload %{
    "location" => %{
      "name" => "Nairobi",
      "region" => "Nairobi",
      "country" => "Kenya",
      "tz_id" => "Africa/Nairobi"
    },
    "current" => %{
      "last_updated" => "2026-11-10 09:15",
      "temp_c" => 24.4,
      "feelslike_c" => 25.6,
      "humidity" => 51,
      "wind_kph" => 4.2,
      "is_day" => 1,
      "condition" => %{"text" => "Overcast", "code" => 1009}
    },
    "forecast" => %{
      "forecastday" => [
        %{
          "date" => "2026-11-10",
          "day" => %{
            "maxtemp_c" => 28.4,
            "mintemp_c" => 17.2,
            "condition" => %{"text" => "Overcast", "code" => 1009}
          },
          "hour" => [
            %{"time" => "2026-11-10 08:00", "temp_c" => 22.0},
            %{"time" => "2026-11-10 09:00", "temp_c" => 23.6},
            %{"time" => "2026-11-10 10:00", "temp_c" => 25.2},
            %{"time" => "2026-11-10 11:00", "temp_c" => 26.8},
            %{"time" => "2026-11-10 12:00", "temp_c" => 27.4},
            %{"time" => "2026-11-10 13:00", "temp_c" => 28.1},
            %{"time" => "2026-11-10 14:00", "temp_c" => 27.6},
            %{"time" => "2026-11-10 15:00", "temp_c" => 26.2}
          ]
        },
        %{
          "date" => "2026-11-11",
          "day" => %{
            "maxtemp_c" => 27.1,
            "mintemp_c" => 16.8,
            "condition" => %{"text" => "Light rain", "code" => 1183}
          },
          "hour" => []
        },
        %{
          "date" => "2026-11-12",
          "day" => %{
            "maxtemp_c" => 29.6,
            "mintemp_c" => 18.0,
            "condition" => %{"text" => "Sunny", "code" => 1000}
          },
          "hour" => []
        }
      ]
    }
  }

  setup do
    Weather.clear_cache()

    on_exit(fn ->
      Application.delete_env(:xpressbus, :weather_forecast_override)
      Weather.clear_cache()
    end)

    :ok
  end

  describe "condition_for/1" do
    test "maps WMO codes to labels and glyphs" do
      assert Weather.condition_for(0) == {"Clear sky", :clear}
      assert Weather.condition_for(1) == {"Mainly clear", :clear}
      assert Weather.condition_for(2) == {"Partly cloudy", :partly_cloudy}
      assert Weather.condition_for(3) == {"Overcast", :cloud}
      assert Weather.condition_for(45) == {"Foggy", :fog}
      assert Weather.condition_for(61) == {"Light rain", :rain}
      assert Weather.condition_for(95) == {"Thunderstorm", :storm}
    end

    test "unknown and missing codes fall back to a cloud" do
      assert Weather.condition_for(999) == {"Cloudy", :cloud}
      assert Weather.condition_for(nil) == {"Cloudy", :cloud}
    end
  end

  describe "parse_forecast/2" do
    test "builds display-ready current conditions" do
      forecast = Weather.parse_forecast(%{name: "Nairobi", country: "Kenya"}, @payload)

      assert forecast.location == %{name: "Nairobi", country: "Kenya"}
      assert forecast.temperature == 24
      assert forecast.feels_like == 26
      assert forecast.condition == "Overcast"
      assert forecast.icon == :cloud
      assert forecast.high == 28
      assert forecast.low == 17
      assert forecast.humidity == 51
      assert forecast.wind == 4
      assert forecast.is_day == true
      assert forecast.timezone == "Africa/Nairobi"
    end

    test "returns the next hours starting with the current hour" do
      forecast = Weather.parse_forecast(%{name: "Nairobi", country: "Kenya"}, @payload)

      assert length(forecast.hourly) == 7
      assert hd(forecast.hourly) == %{time: "2026-11-10T09:00", label: "09:00", temperature: 24}
      assert List.last(forecast.hourly).label == "15:00"
    end

    test "summarises three days with weekday labels" do
      forecast = Weather.parse_forecast(%{name: "Nairobi", country: "Kenya"}, @payload)

      assert [today, tomorrow, third] = forecast.daily
      assert today.label == "Today"
      assert today.icon == :cloud
      assert {today.high, today.low} == {28, 17}

      assert tomorrow.label == "Wed"
      assert tomorrow.icon == :rain
      assert third.label == "Thu"
      assert third.icon == :clear
    end

    test "tolerates a payload without hourly or daily sections" do
      forecast = Weather.parse_forecast(%{name: "Nowhere", country: ""}, %{})

      assert forecast.temperature == nil
      assert forecast.high == nil
      assert forecast.hourly == []
      assert forecast.daily == []
    end
  end

  describe "WeatherAPI provider" do
    test "maps WeatherAPI condition codes to labels and glyphs" do
      assert Weather.weatherapi_condition(%{"code" => 1000, "text" => "Sunny"}) ==
               {"Sunny", :clear}

      assert Weather.weatherapi_condition(%{"code" => 1003, "text" => "Partly cloudy"}) ==
               {"Partly cloudy", :partly_cloudy}

      assert Weather.weatherapi_condition(%{"code" => 1183, "text" => "Light rain"}) ==
               {"Light rain", :rain}

      assert Weather.weatherapi_condition(%{"code" => 1276, "text" => "Thunder"}) ==
               {"Thunder", :storm}

      assert Weather.weatherapi_condition(%{"code" => 1213, "text" => "Patchy snow"}) ==
               {"Patchy snow", :snow}

      assert Weather.weatherapi_condition(%{"code" => 1135, "text" => "Mist"}) ==
               {"Mist", :fog}

      assert Weather.weatherapi_condition(nil) == {"Cloudy", :cloud}
    end

    test "parses a WeatherAPI forecast into the same display shape as Open-Meteo" do
      forecast =
        Weather.parse_weatherapi_forecast(
          %{name: "Nairobi", country: "Kenya"},
          @weatherapi_payload
        )

      assert forecast.location == %{name: "Nairobi", country: "Kenya"}
      assert forecast.temperature == 24
      assert forecast.feels_like == 26
      assert forecast.condition == "Overcast"
      assert forecast.icon == :cloud
      assert forecast.high == 28
      assert forecast.low == 17
      assert forecast.humidity == 51
      assert forecast.wind == 4
      assert forecast.is_day == true
      assert forecast.timezone == "Africa/Nairobi"

      assert length(forecast.hourly) == 7
      assert hd(forecast.hourly) == %{time: "2026-11-10 09:00", label: "09:00", temperature: 24}
      assert List.last(forecast.hourly).label == "15:00"

      assert [today, tomorrow, third] = forecast.daily
      assert today.label == "Today"
      assert {today.high, today.low} == {28, 17}
      assert today.icon == :cloud
      assert tomorrow.icon == :rain
      assert third.icon == :clear
    end

    test "tolerates a WeatherAPI payload without forecast data" do
      forecast = Weather.parse_weatherapi_forecast(%{name: "Nowhere", country: ""}, %{})

      assert forecast.temperature == nil
      assert forecast.high == nil
      assert forecast.hourly == []
      assert forecast.daily == []
    end
  end

  describe "load/1" do
    test "returns the configured forecast override without network access" do
      forecast = %{location: %{name: "Mombasa", country: "Kenya"}, temperature: 30}
      Application.put_env(:xpressbus, :weather_forecast_override, forecast)

      assert Weather.load("Mombasa") == {:ok, forecast}
      assert Weather.load(nil) == {:ok, forecast}
    end

    test "accepts a one-argument override function" do
      Application.put_env(
        :xpressbus,
        :weather_forecast_override,
        fn query -> {:ok, %{queried: query}} end
      )

      assert Weather.load("Kisumu") == {:ok, %{queried: "Kisumu"}}
    end

    test "refuses to fetch when weather is disabled" do
      assert Weather.load("Nairobi") == {:error, :disabled}
    end

    test "validates the city name before any request" do
      assert Weather.load("   ") == {:error, :empty_query}
      assert Weather.load(123) == {:error, :invalid_location}
    end
  end
end
