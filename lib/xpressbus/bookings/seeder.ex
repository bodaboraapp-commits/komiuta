defmodule Xpressbus.Bookings.Seeder do
  alias Xpressbus.Bookings.Scraper
  alias Xpressbus.Bookings.Cleaner
  alias Xpressbus.BusOperators.Scraper, as: OperatorsScraper
  import Ecto.Query
  require Logger

  @moduledoc """
  Seeds the local database with bus schedule data pulled from BuuPass.

  Iterates over every configured city-pair route and pulls availability
  for the current day plus a configurable number of future days. Each
  scrape is delegated to `Xpressbus.Bookings.Scraper`, which persists
  results to the database.

  Used by the background `SyncServer` and the `mix buupass.pull` task.
  """

  # @cities [
  #   "Nairobi",
  #   "Mombasa",
  #   "Kisumu",
  #   "Eldoret",
  #   "Nakuru",
  #   "Kakamega",
  #   "Kitale",
  #   "Bungoma",
  #   "Thika",
  #   "Ukunda",
  #   "Malindi"
  # ]

  @days_to_pull 7
  @request_delay_ms 2_000

  @doc """
  Pulls bus data from BuuPass.

  First attempts to discover new operators and routes from the BuuPass sitemap.
  Then iterates over active routes and pulls availability for the next #{@days_to_pull} days.
  """
  def run do
    Logger.info("🚀 Starting Industrial Data Sync from BuuPass...")

    # 1. Discover and Sync Routes/Operators from Sitemap
    sync_from_sitemap()

    # 2. Additional Operator Sync (Logos & Fallbacks)
    Logger.info("🏢 Syncing bus operators...")
    OperatorsScraper.sync()

    # 3. Iterate over discovered routes and pull bus data
    pull_bus_data()

    # 4. Cleanup stale data
    Cleaner.clean_stale_buses()

    Logger.info("✅ Industrial Data Sync complete.")
  end

  def sync_from_sitemap do
    url = "https://buupass.com/sitemap.xml"
    Logger.info("🌐 Fetching sitemap: #{url}")

    case Req.get(url, headers: [{"user-agent", "Mozilla/5.0"}], receive_timeout: 15_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        sync_operators_from_sitemap(body)
        sync_routes_from_sitemap(body)

      _ ->
        Logger.warning("⚠️ Could not fetch sitemap. Using hardcoded defaults.")
    end
  end

  defp sync_operators_from_sitemap(body) do
    operators = Regex.scan(~r|<loc>https://buupass.com/operator/(.*?)</loc>|, body)
    Logger.info("🏢 Discovered #{length(operators)} operators in sitemap.")

    Enum.each(operators, fn [_, slug] ->
      # Industrial Name Restoration: Convert "easy-coach" to "Easy Coach"
      name =
        slug
        |> String.split("-")
        |> Enum.map(fn
          "poa" -> "Poa"
          "ena" -> "Ena"
          word -> String.capitalize(word)
        end)
        |> Enum.join(" ")

      Xpressbus.BusOperators.upsert_bus_operator(%{
        name: name,
        active: true
      })
    end)
  end

  defp sync_routes_from_sitemap(body) do
    routes = Regex.scan(~r|<loc>https://buupass.com/buses/(.*?)</loc>|, body)
    Logger.info("🛣️ Discovered #{length(routes)} routes in sitemap.")

    Enum.each(routes, fn [_, path] ->
      case String.split(path, "-to-") do
        [from, to] ->
          Xpressbus.Routes.ensure_route(URI.decode(from), URI.decode(to))

        _ ->
          :ok
      end
    end)
  end

  defp pull_bus_data do
    dates = future_dates(@days_to_pull)
    # Get active routes from DB
    routes = Xpressbus.Repo.all(from(r in Xpressbus.Routes.Route, where: r.active == true))
    total = length(routes) * length(dates)

    Logger.info(
      "📋 Processing #{total} requests: #{length(routes)} route(s) x #{length(dates)} date(s)."
    )

    Enum.with_index(routes, fn %{origin: from, destination: to}, route_index ->
      Enum.with_index(dates, fn date, date_index ->
        index = route_index * length(dates) + date_index + 1
        Logger.info("[#{index}/#{total}] 🔍 Syncing: #{from} → #{to} on #{date}")

        scrape_with_recovery(from, to, date)
        Process.sleep(@request_delay_ms)
      end)
    end)
  end

  defp scrape_with_recovery(from, to, date) do
    try do
      Scraper.search(from, to, date)
    rescue
      error ->
        Logger.error("❌ Error syncing #{from} → #{to} on #{date}: #{Exception.message(error)}")
    end
  end

  defp future_dates(count) do
    today = Date.utc_today()

    Enum.map(0..(count - 1), fn offset ->
      today
      |> Date.add(offset)
      |> Date.to_string()
    end)
  end

  # defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  # defp format_duration(ms), do: "#{Float.round(ms / 1000, 1)}s"
end
