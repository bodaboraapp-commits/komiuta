defmodule Xpressbus.Jobs.HotelSyncScheduler do
  @moduledoc """
  Checks whether the two-day Google hotel refresh is due while the app is awake.

  Render's free web instance sleeps when idle, so the scheduled GitHub Actions
  workflow also requests the hotels page every two days. The page load starts
  the same due check, which keeps the data fresh even with no visitors.
  """

  use GenServer

  @check_interval :timer.hours(3)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    if enabled?() do
      Process.send_after(self(), :check, :timer.minutes(1))
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:check, state) do
    if enabled?() do
      Task.start(fn -> Xpressbus.GoogleHotelSync.run_if_due() end)
      Process.send_after(self(), :check, @check_interval)
    end

    {:noreply, state}
  end

  defp enabled? do
    Application.get_env(:xpressbus, :hotel_sync_scheduler_enabled, false)
  end
end
