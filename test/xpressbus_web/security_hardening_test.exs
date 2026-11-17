defmodule XpressbusWeb.SecurityHardeningTest do
  use XpressbusWeb.ConnCase, async: false

  alias Xpressbus.Admins
  alias XpressbusWeb.Plugs.IpThrottle
  alias XpressbusWeb.Plugs.RequestGuard

  setup do
    IpThrottle.reset()
    :ok
  end

  describe "request guard" do
    test "normal requests pass through" do
      conn = Plug.Test.conn(:get, "/dashboard?tab=bus")
      refute RequestGuard.call(conn, []).halted
    end

    test "rejects NUL bytes in the raw query string" do
      conn = Plug.Test.conn(:get, "/?q=test")
      conn = %{conn | query_string: "q=" <> <<0>>}

      result = RequestGuard.call(conn, [])

      assert result.halted
      assert result.status == 400
    end

    test "rejects oversized paths and query strings" do
      long_path = Plug.Test.conn(:get, "/" <> String.duplicate("a", 3_000))
      assert RequestGuard.call(long_path, []).status == 414

      long_query = Plug.Test.conn(:get, "/?" <> String.duplicate("a", 9_000))
      assert RequestGuard.call(long_query, []).status == 414
    end
  end

  describe "brute-force throttles" do
    test "admin password attempts are throttled per IP" do
      params = %{"admin" => %{"email" => "nobody@example.com", "password" => "wrong"}}

      for _ <- 1..5 do
        response = post(build_conn(), ~p"/admin/auth", params)
        refute response.status == 429
      end

      blocked = post(build_conn(), ~p"/admin/auth", params)

      assert redirected_to(blocked) == "/admin/login"
      assert Phoenix.Flash.get(blocked.assigns.flash, :error) =~ "Too many attempts"
      assert [retry_after] = get_resp_header(blocked, "retry-after")
      assert String.to_integer(retry_after) > 0
    end

    test "admin password attempts are also limited per email across IPs" do
      {:ok, admin} =
        Admins.create_admin(%{
          email: "locked-admin@example.com",
          name: "Locked Admin",
          hashed_password: Admins.hash_password("correct-password")
        })

      params = %{"admin" => %{"email" => admin.email, "password" => "wrong"}}

      for attempt <- 1..5 do
        conn =
          build_conn()
          |> put_req_header("x-forwarded-for", "198.51.100.#{attempt}")

        response = post(conn, ~p"/admin/auth", params)

        assert Phoenix.Flash.get(response.assigns.flash, :error) == "Invalid email or password"
      end

      blocked =
        build_conn()
        |> put_req_header("x-forwarded-for", "198.51.100.99")
        |> post(~p"/admin/auth", %{
          "admin" => %{"email" => admin.email, "password" => "correct-password"}
        })

      assert blocked.status == 429

      assert Phoenix.Flash.get(blocked.assigns.flash, :error) =~
               "Too many failed sign-in attempts"
    end

    test "agent sign-in requests are throttled per IP" do
      params = %{"agent" => %{"identifier" => "0712000999"}}

      for _ <- 1..8 do
        _response = post(build_conn(), ~p"/agent/auth", params)
      end

      blocked = post(build_conn(), ~p"/agent/auth", params)

      assert redirected_to(blocked) == "/agent/login"
      assert Phoenix.Flash.get(blocked.assigns.flash, :error) =~ "Too many attempts"
    end

    test "traveller registration is throttled per IP" do
      params = %{"user" => %{"name" => "Bot", "email" => "bot@example.com"}}

      for _ <- 1..5 do
        _response = post(build_conn(), ~p"/user/register", params)
      end

      blocked = post(build_conn(), ~p"/user/register", params)

      assert redirected_to(blocked) == "/user/signup"
      assert Phoenix.Flash.get(blocked.assigns.flash, :error) =~ "Too many attempts"
    end
  end

  describe "raw injection surface" do
    test "no database query interpolates untrusted input into SQL" do
      root = Path.expand("../..", __DIR__)

      sources =
        Path.join(root, "lib/**/*.ex")
        |> Path.wildcard()
        |> Enum.map(&{&1, File.read!(&1)})

      for {file, source} <- sources do
        refute source =~ ~r/Repo\.(query|query!)\(\s*"[^"]*#\{/s,
               "raw SQL interpolation found in #{file}"

        refute source =~ ~r/fragment\(\s*"[^"]*#\{/s,
               "interpolated SQL fragment found in #{file}"
      end
    end

    test "no application code evaluates arbitrary code or shells out" do
      root = Path.expand("../..", __DIR__)

      sources =
        Path.join(root, "lib/**/*.ex")
        |> Path.wildcard()
        |> Enum.map(&{&1, File.read!(&1)})

      for {file, source} <- sources do
        refute source =~ ~r/Code\.(eval|eval_string|eval_quoted)/,
               "dynamic code evaluation found in #{file}"

        refute source =~ ~r/(:os\.cmd|System\.cmd|System\.shell)/,
               "shell execution found in #{file}"
      end
    end
  end
end
