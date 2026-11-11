defmodule Xpressbus.ContentCacheTest do
  use ExUnit.Case, async: false

  alias Xpressbus.ContentCache

  setup do
    ContentCache.invalidate_all()
    on_exit(fn -> ContentCache.invalidate_all() end)
    :ok
  end

  test "fetches once within the TTL and recomputes after expiry" do
    within_key = {:content_cache_within_test, make_ref()}
    expiry_key = {:content_cache_expiry_test, make_ref()}
    calls = :counters.new(1, [:atomics])

    first =
      ContentCache.fetch(
        within_key,
        fn ->
          :counters.add(calls, 1, 1)
          :cached
        end,
        10_000
      )

    second =
      ContentCache.fetch(
        within_key,
        fn ->
          :counters.add(calls, 1, 1)
          :fresh
        end,
        10_000
      )

    assert first == :cached
    assert second == :cached
    assert :counters.get(calls, 1) == 1

    ContentCache.fetch(expiry_key, fn -> :before_expiry end, 1)
    Process.sleep(5)

    expired = ContentCache.fetch(expiry_key, fn -> :after_expiry end, 1)

    assert expired == :after_expiry
  end

  test "invalidates only keys under a prefix" do
    prefix = {:content_cache_prefix_test, make_ref()}
    other = {:content_cache_other_test, make_ref()}

    ContentCache.fetch({prefix, :one}, fn -> :one end, 10_000)
    ContentCache.fetch({prefix, :two}, fn -> :two end, 10_000)
    ContentCache.fetch({other, :one}, fn -> :other end, 10_000)

    ContentCache.invalidate(prefix)

    assert ContentCache.fetch({prefix, :one}, fn -> :recomputed end, 10_000) == :recomputed
    assert ContentCache.fetch({other, :one}, fn -> :recomputed end, 10_000) == :other
  end

  test "returns fresh values when a cache entry is cleared" do
    key = {:content_cache_clear_test, make_ref()}

    assert ContentCache.fetch(key, fn -> :first end, 10_000) == :first
    ContentCache.invalidate_all()
    assert ContentCache.fetch(key, fn -> :second end, 10_000) == :second
  end
end
