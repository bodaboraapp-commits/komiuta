defmodule XpressbusWeb.Plugs.IpThrottleTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias XpressbusWeb.Plugs.IpThrottle

  setup do
    IpThrottle.reset()
    :ok
  end

  test "allows requests under the limit and blocks the next one" do
    opts = IpThrottle.init(bucket: :test_auth, limit: 2, window: 60)

    first = IpThrottle.call(conn(:post, "/user/auth"), opts)
    second = IpThrottle.call(conn(:post, "/user/auth"), opts)
    third = IpThrottle.call(conn(:post, "/user/auth"), opts)

    refute first.halted
    refute second.halted
    assert third.halted
    assert third.status == 302
    assert get_resp_header(third, "location") == ["/user/login"]
    assert [retry_after] = get_resp_header(third, "retry-after")
    assert String.to_integer(retry_after) > 0
  end

  test "buckets are isolated from each other" do
    auth = IpThrottle.init(bucket: :test_bucket_one, limit: 1, window: 60)
    verify = IpThrottle.init(bucket: :test_bucket_two, limit: 1, window: 60)

    refute IpThrottle.call(conn(:post, "/user/auth"), auth).halted
    assert IpThrottle.call(conn(:post, "/user/auth"), auth).halted

    # A different bucket keeps its own counter.
    refute IpThrottle.call(conn(:post, "/user/verify"), verify).halted
  end

  test "different client IPs have independent counters" do
    opts = IpThrottle.init(bucket: :test_ip, limit: 1, window: 60)

    first = conn(:post, "/user/auth") |> Map.put(:remote_ip, {203, 0, 113, 5})
    second = conn(:post, "/user/auth") |> Map.put(:remote_ip, {203, 0, 113, 6})

    refute IpThrottle.call(first, opts).halted
    refute IpThrottle.call(second, opts).halted
  end

  test "reset/0 clears counters" do
    opts = IpThrottle.init(bucket: :test_reset, limit: 1, window: 60)

    refute IpThrottle.call(conn(:post, "/user/auth"), opts).halted
    assert IpThrottle.call(conn(:post, "/user/auth"), opts).halted

    IpThrottle.reset()
    refute IpThrottle.call(conn(:post, "/user/auth"), opts).halted
  end

  test "allow?/4 supports LiveView-driven throttling" do
    ip = "203.0.113.9"

    assert {:ok, 1} = IpThrottle.allow?(:ticket_lookup, ip, 2, 60)
    assert {:ok, 2} = IpThrottle.allow?(:ticket_lookup, ip, 2, 60)
    assert {:error, retry_after} = IpThrottle.allow?(:ticket_lookup, ip, 2, 60)
    assert retry_after > 0

    # Another IP is unaffected.
    assert {:ok, 1} = IpThrottle.allow?(:ticket_lookup, "203.0.113.10", 2, 60)
  end
end
