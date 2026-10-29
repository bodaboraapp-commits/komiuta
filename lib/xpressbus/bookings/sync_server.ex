defmodule Xpressbus.Bookings.SyncServer do
  use GenServer
  alias Xpressbus.Bookings.Seeder
  require Logger

  # Run every 6 hours
  @interval 6 * 60 * 60 * 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Schedule the first sync in 1 minute
    Process.send_after(self(), :sync, 60 * 1000)
    {:ok, state}
  end

  def handle_info(:sync, state) do
    # Only run sync if enabled in config, default to false in dev to save connections
    if Application.get_env(:xpressbus, :enable_background_sync, false) do
      Logger.info("🔄 Background Sync: Updating BuuPass data...")
      Task.start(fn -> Seeder.run() end)
    else
      Logger.info("🔄 Background Sync: Disabled (Check config)")
    end

    # Schedule next sync
    schedule_sync()
    {:noreply, state}
  end

  defp schedule_sync do
    Process.send_after(self(), :sync, @interval)
  end
end
