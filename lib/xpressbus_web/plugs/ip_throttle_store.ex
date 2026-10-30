defmodule XpressbusWeb.Plugs.IpThrottleStore do
  @moduledoc false
  # Owns the ETS table used by `XpressbusWeb.Plugs.IpThrottle` so counters
  # survive individual request processes. Also sweeps stale windows.

  use GenServer

  @table :xpressbus_ip_throttle
  @sweep_interval_ms 60_000
  @max_age_seconds 3_600

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    table =
      try do
        :ets.new(@table, [
          :named_table,
          :public,
          :set,
          read_concurrency: true,
          write_concurrency: true
        ])
      rescue
        ArgumentError -> :ets.whereis(@table)
      end

    Process.send_after(self(), :sweep, @sweep_interval_ms)
    {:ok, table}
  end

  @impl true
  def handle_info(:sweep, table) do
    cutoff = System.system_time(:second) - @max_age_seconds

    :ets.select_delete(table, [
      {{:_, :"$1", :_}, [{:<, :"$1", cutoff}], [true]}
    ])

    Process.send_after(self(), :sweep, @sweep_interval_ms)
    {:noreply, table}
  end

  def handle_info(_message, table), do: {:noreply, table}
end
