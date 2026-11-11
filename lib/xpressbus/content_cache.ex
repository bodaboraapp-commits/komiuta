defmodule Xpressbus.ContentCache do
  @moduledoc """
  Small in-process content cache used by read-heavy public pages and admin
  dashboards.

  Entries expire automatically through a monotonic timestamp checked on read,
  so a stale entry can never be served indefinitely. The cache is deliberately
  in-process and disposable: a missing table, restart or cold node simply
  falls back to the database. Writes that change catalogue content should call
  `invalidate/1` or `invalidate_all/0`, while the TTL protects against any
  forgotten call sites.
  """

  use GenServer

  @table :xpressbus_content_cache
  @default_ttl_ms 60_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    {:ok, %{}}
  end

  @doc "Returns a cached value or computes and stores it for `ttl_ms`."
  def fetch(key, fun, ttl_ms \\ @default_ttl_ms) when is_function(fun, 0) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        value

      _other ->
        value = fun.()
        :ets.insert(@table, {key, value, now + ttl_ms})
        value
    end
  rescue
    ArgumentError ->
      # Table is not available (e.g. during shutdown); skip caching.
      fun.()
  end

  @doc "Drops every cache entry whose key starts with `prefix`."
  def invalidate(prefix) do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _table -> :ets.match_delete(@table, {{prefix, :_}, :_, :_})
    end

    :ok
  end

  @doc "Drops all cached content, e.g. after a catalogue import."
  def invalidate_all do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _table -> :ets.delete_all_objects(@table)
    end

    :ok
  end

  def clear, do: invalidate_all()
end
