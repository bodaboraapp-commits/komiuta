defmodule Xpressbus.Routes.Seeder do
  require Logger
  alias Xpressbus.Repo
  alias Xpressbus.Routes.Route

  @route_data [
    {"Nairobi", "Mombasa", "480 km", "10h 30m"},
    {"Nairobi", "Kisumu", "340 km", "6h 45m"},
    {"Nairobi", "Eldoret", "260 km", "5h 15m"},
    {"Nairobi", "Nakuru", "150 km", "2h 45m"},
    {"Nairobi", "Kakamega", "400 km", "8h 00m"},
    {"Nairobi", "Kitale", "320 km", "6h 30m"},
    {"Nairobi", "Bungoma", "380 km", "7h 45m"},
    {"Nairobi", "Thika", "65 km", "1h 15m"},
    {"Nairobi", "Ukunda", "450 km", "10h 00m"},
    {"Nairobi", "Malindi", "490 km", "11h 30m"},
    {"Mombasa", "Nairobi", "480 km", "10h 30m"},
    {"Mombasa", "Kisumu", "780 km", "14h 00m"},
    {"Mombasa", "Eldoret", "720 km", "13h 00m"},
    {"Mombasa", "Nakuru", "630 km", "12h 15m"},
    {"Kisumu", "Nairobi", "340 km", "6h 45m"},
    {"Kisumu", "Mombasa", "780 km", "14h 00m"},
    {"Kisumu", "Eldoret", "180 km", "3h 30m"},
    {"Kisumu", "Kakamega", "50 km", "1h 00m"},
    {"Kisumu", "Kitale", "140 km", "2h 45m"},
    {"Eldoret", "Nairobi", "260 km", "5h 15m"},
    {"Eldoret", "Mombasa", "720 km", "13h 00m"},
    {"Eldoret", "Kisumu", "180 km", "3h 30m"},
    {"Eldoret", "Kitale", "90 km", "1h 45m"},
    {"Eldoret", "Bungoma", "120 km", "2h 15m"},
    {"Nakuru", "Nairobi", "150 km", "2h 45m"},
    {"Nakuru", "Mombasa", "630 km", "12h 15m"},
    {"Nakuru", "Eldoret", "120 km", "2h 00m"},
    {"Thika", "Nairobi", "65 km", "1h 15m"},
    {"Ukunda", "Nairobi", "450 km", "10h 00m"},
    {"Malindi", "Nairobi", "490 km", "11h 30m"}
  ]

  def run do
    Logger.info("🌱 Seeding routes from BuuPass data...")

    Enum.each(@route_data, fn {origin, destination, distance, duration} ->
      case Repo.get_by(Route, origin: origin, destination: destination) do
        nil ->
          %Route{}
          |> Route.changeset(%{
            origin: origin,
            destination: destination,
            distance: distance,
            duration: duration,
            active: true
          })
          |> Repo.insert!()

          Logger.info("  ✅ Created route: #{origin} → #{destination}")

        _route ->
          Logger.info("  ⏭️  Route already exists: #{origin} → #{destination}")
      end
    end)

    total = length(@route_data)
    Logger.info("✅ Route seeding complete. #{total} routes processed.")
  end
end
