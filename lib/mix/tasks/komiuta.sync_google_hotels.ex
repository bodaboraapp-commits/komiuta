defmodule Mix.Tasks.Komiuta.SyncGoogleHotels do
  @shortdoc "Refreshes Google Places hotel data and emails the report"
  @moduledoc """
  Forces a full Google Places refresh for the curated Chyllz hotels and sends
  the operations report to the configured alert address.

      mix komiuta.sync_google_hotels
  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    case Xpressbus.GoogleHotelSync.run(force: true) do
      {:ok, run} ->
        Mix.shell().info(
          "Google hotel sync #{run.status}: #{run.matched_count}/#{run.hotels_count} matched"
        )

      other ->
        Mix.shell().info("Google hotel sync skipped: #{inspect(other)}")
    end
  end
end
