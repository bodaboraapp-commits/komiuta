defmodule XpressbusWeb.AuthThrottleTest do
  use XpressbusWeb.ConnCase

  alias XpressbusWeb.Plugs.IpThrottle

  setup do
    IpThrottle.reset()
    :ok
  end

  test "per-IP throttle blocks /user/auth after the configured limit", %{conn: conn} do
    params = %{"user" => %{"identifier" => "nobody@example.com"}}

    for _ <- 1..10 do
      response = post(conn, ~p"/user/auth", params)
      refute Phoenix.Flash.get(response.assigns.flash, :error) =~ "Too many attempts"
    end

    blocked = post(conn, ~p"/user/auth", params)

    assert redirected_to(blocked) == "/user/login"
    assert Phoenix.Flash.get(blocked.assigns.flash, :error) =~ "Too many attempts"
    assert [retry_after] = get_resp_header(blocked, "retry-after")
    assert String.to_integer(retry_after) > 0
  end

  test "the verify endpoint has its own budget", %{conn: conn} do
    params = %{"user" => %{"code" => "000000"}}

    for _ <- 1..5 do
      _ = post(conn, ~p"/user/verify", params)
    end

    # The auth bucket is untouched by verify traffic.
    auth_response =
      post(conn, ~p"/user/auth", %{"user" => %{"identifier" => "nobody@example.com"}})

    refute Phoenix.Flash.get(auth_response.assigns.flash, :error) =~ "Too many attempts"
  end
end
