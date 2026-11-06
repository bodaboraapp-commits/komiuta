defmodule XpressbusWeb.AgentAuthTest do
  use XpressbusWeb.ConnCase

  import Ecto.Query
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Xpressbus.Agents
  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.Agents.AgentLoginCode
  alias Xpressbus.Buses
  alias Xpressbus.BusOperators
  alias Xpressbus.Repo
  alias Xpressbus.Tickets

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "full_name" => "Jane Agent",
        "business_name" => "Jane Travel",
        "email" => "jane.login@example.com",
        "phone" => "0712345678",
        "city" => "Nairobi",
        "payout_method" => "mpesa"
      },
      overrides
    )
  end

  defp create_application(overrides \\ %{}) do
    {:ok, application} = Agents.create_application(attrs(overrides))
    application
  end

  defp code_from_email do
    {:email, email} = assert_email_sent()
    [_, code] = Regex.run(~r/\b(\d{6})\b/, email.text_body)
    code
  end

  test "agent login page is phone/SMS first with no visible security puzzle", %{conn: conn} do
    html = conn |> get(~p"/agent/login") |> html_response(200)

    assert html =~ "Agent sign in"
    assert html =~ "Phone number"

    assert html =~ "firebase-sms-auth" or html =~ "SMS sign-in is not configured yet"

    refute html =~ ~s(action="/agent/auth")
    refute html =~ "Send SMS code"
  end

  describe "Firebase phone OTP verification" do
    test "rejects a missing token", %{conn: conn} do
      conn = post(conn, ~p"/agent/firebase/verify", %{})
      assert conn.status == 400
      assert json_response(conn, 400)["error"] =~ "Missing"
    end

    test "logs in the agent whose application phone Firebase verified", %{conn: conn} do
      application = create_application()

      Application.put_env(:xpressbus, :firebase_lookup_fun, fn token ->
        assert token == "agent-firebase-token"
        {:ok, "+254712345678"}
      end)

      on_exit(fn -> Application.delete_env(:xpressbus, :firebase_lookup_fun) end)

      conn = post(conn, ~p"/agent/firebase/verify", %{"id_token" => "agent-firebase-token"})

      assert %{"ok" => true, "redirect" => "/agent/verify-email"} = json_response(conn, 200)
      assert get_session(conn, :agent_id) == application.id
    end

    test "returns not_found when the verified phone has no agent application", %{conn: conn} do
      Application.put_env(:xpressbus, :firebase_lookup_fun, fn _token ->
        {:ok, "+254700000001"}
      end)

      on_exit(fn -> Application.delete_env(:xpressbus, :firebase_lookup_fun) end)

      conn = post(conn, ~p"/agent/firebase/verify", %{"id_token" => "agent-firebase-token"})

      assert conn.status == 404
      assert json_response(conn, 404)["error"] =~ "No agent application"
    end

    test "rejects an invalid Firebase token", %{conn: conn} do
      Application.put_env(:xpressbus, :firebase_lookup_fun, fn _token ->
        {:error, :invalid_token}
      end)

      on_exit(fn -> Application.delete_env(:xpressbus, :firebase_lookup_fun) end)

      conn = post(conn, ~p"/agent/firebase/verify", %{"id_token" => "bad-token"})

      assert conn.status == 401
    end
  end

  test "requesting a code emails it and redirects to verification", %{conn: conn} do
    application = create_application()

    conn =
      post(conn, ~p"/agent/auth", %{
        "agent" => %{"identifier" => "jane.login@example.com"}
      })

    assert redirected_to(conn) == "/agent/verify"
    assert get_session(conn, :agent_login_id) == application.id
    refute get_session(conn, :agent_id)

    assert_email_sent(fn email ->
      assert email.subject =~ "KOMIUTA Agent login code"
      assert email.to == [{"Jane Agent", "jane.login@example.com"}]
    end)
  end

  test "the verification page requires a pending login", %{conn: conn} do
    conn = get(conn, ~p"/agent/verify")

    assert redirected_to(conn) == "/agent/login"
  end

  test "a wrong code does not start an agent session", %{conn: conn} do
    _application = create_application()
    conn = post(conn, ~p"/agent/auth", %{"agent" => %{"identifier" => "jane.login@example.com"}})
    code = code_from_email()
    wrong = if code == "000000", do: "111111", else: "000000"

    conn = post(recycle(conn), ~p"/agent/verify", %{"agent" => %{"code" => wrong}})

    assert html_response(conn, 200) =~ "That code is incorrect"
    refute get_session(conn, :agent_id)
  end

  test "the correct code logs the agent in and consumes the code", %{conn: conn} do
    application = create_application()
    conn = post(conn, ~p"/agent/auth", %{"agent" => %{"identifier" => "jane.login@example.com"}})
    code = code_from_email()

    conn = post(recycle(conn), ~p"/agent/verify", %{"agent" => %{"code" => code}})

    assert redirected_to(conn) == "/agent/verify-email"
    assert get_session(conn, :agent_id) == application.id
    refute get_session(conn, :agent_login_id)

    login_code =
      Repo.one(
        from(c in AgentLoginCode,
          where: c.agent_application_id == ^application.id,
          order_by: [desc: c.inserted_at],
          limit: 1
        )
      )

    refute is_nil(login_code.consumed_at)
  end

  test "phone login texts the sign-in code", %{conn: conn} do
    _application = create_application()
    test_pid = self()

    Application.put_env(:xpressbus, :sms_send_fun, fn to, message ->
      send(test_pid, {:agent_sms, to, message})
      {:ok, %{provider: :test}}
    end)

    on_exit(fn -> Application.delete_env(:xpressbus, :sms_send_fun) end)

    conn = post(conn, ~p"/agent/auth", %{"agent" => %{"identifier" => "0712345678"}})

    assert redirected_to(conn) == "/agent/verify"
    assert_receive {:agent_sms, "+254712345678", message}
    assert message =~ "sign-in code"

    assert_email_sent(fn email ->
      assert email.subject =~ "KOMIUTA Agent login code"
      assert email.to == [{"Jane Agent", "jane.login@example.com"}]
    end)
  end

  test "phone login falls back to email when SMS is unavailable", %{conn: conn} do
    _application = create_application()

    conn = post(conn, ~p"/agent/auth", %{"agent" => %{"identifier" => "0712345678"}})

    assert redirected_to(conn) == "/agent/verify"

    assert_email_sent(fn email ->
      assert email.subject =~ "KOMIUTA Agent login code"
      assert email.to == [{"Jane Agent", "jane.login@example.com"}]
    end)
  end

  test "email verification gate sends a code and unlocks the account", %{conn: conn} do
    application = create_application()
    conn = post(conn, ~p"/agent/auth", %{"agent" => %{"identifier" => "jane.login@example.com"}})
    code = code_from_email()
    conn = post(recycle(conn), ~p"/agent/verify", %{"agent" => %{"code" => code}})

    assert redirected_to(conn) == "/agent/verify-email"

    gate = get(conn, ~p"/agent/verify-email")
    html = html_response(gate, 200)
    assert html =~ "Verify your email"
    assert html =~ "jane.login@example.com"

    conn =
      post(recycle(conn), ~p"/agent/verify-email/send", %{
        "email" => "jane.verified@example.com"
      })

    assert redirected_to(conn) == "/agent/verify-email"
    code = code_from_email()

    conn =
      post(recycle(conn), ~p"/agent/verify-email/confirm", %{
        "code" => code
      })

    assert redirected_to(conn) == "/agent/account"

    application = Repo.get!(AgentApplication, application.id)
    assert application.email == "jane.verified@example.com"
    refute is_nil(application.email_verified_at)

    html = conn |> recycle() |> get(~p"/agent/account") |> html_response(200)
    assert html =~ application.business_name
  end

  test "an unknown agent identifier does not send a code", %{conn: conn} do
    conn =
      post(conn, ~p"/agent/auth", %{
        "agent" => %{"identifier" => "missing.agent@example.com"}
      })

    assert html_response(conn, 200) =~ "No agent application was found"
    assert_no_email_sent()
    refute get_session(conn, :agent_login_id)
  end

  test "account requires a session and logout clears it", %{conn: conn} do
    assert conn |> get(~p"/agent/account") |> redirected_to() == "/agent/login"

    application = create_application()

    authed = Plug.Test.init_test_session(build_conn(), %{agent_id: application.id})
    assert authed |> get(~p"/agent/account") |> redirected_to() == "/agent/verify-email"

    {:ok, verified} = Agents.mark_email_verified(application, application.email)
    authed = Plug.Test.init_test_session(build_conn(), %{agent_id: verified.id})

    html = authed |> get(~p"/agent/account") |> html_response(200)
    assert html =~ application.business_name
    assert html =~ application.reference

    logged_out = authed |> get(~p"/agent/logout")
    assert redirected_to(logged_out) == "/agent/login"
    refute get_session(logged_out, :agent_id)
  end

  test "account shows the agent wallet with partner sales", %{conn: conn} do
    {:ok, operator} =
      BusOperators.create_bus_operator(%{name: "Coast Partner", active: true})

    {:ok, bus} =
      Buses.create_bus(%{
        "company" => operator.name,
        "from" => "Nairobi",
        "to" => "Mombasa",
        "travel_date" => Date.utc_today(),
        "departure" => "8:00 AM",
        "arrival" => "3:00 PM",
        "price" => "KSH 1,800",
        "seats" => "[]",
        "bus_operator_id" => operator.id
      })

    {:ok, _ticket} =
      Tickets.create_ticket(%{
        "ticket_id" => "TKT-WALLET-#{System.unique_integer([:positive])}",
        "from" => "Nairobi",
        "to" => "Mombasa",
        "travel_date" => Date.utc_today(),
        "departure" => "8:00 AM",
        "arrival" => "3:00 PM",
        "company" => operator.name,
        "price" => "KSH 1,800",
        "seats" => "[\"1A\"]",
        "passenger_name" => "Wallet Passenger",
        "passenger_phone" => "0712345678",
        "status" => "confirmed",
        "bus_id" => bus.id
      })

    application = create_application(%{"bus_operator_id" => operator.id})
    {:ok, application} = Agents.update_status(application, "approved")
    {:ok, application} = Agents.mark_email_verified(application, application.email)

    authed = Plug.Test.init_test_session(conn, %{agent_id: application.id})
    html = authed |> get(~p"/agent/account") |> html_response(200)

    assert html =~ "Your wallet"
    assert html =~ "Coast Partner"
    assert html =~ "KES 1,800"
    assert html =~ "Confirmed bookings for Coast Partner"
  end

  test "logged-in agents are sent from the signup page to their account" do
    application = create_application()
    authed = Plug.Test.init_test_session(build_conn(), %{agent_id: application.id})

    assert {:error, {:redirect, %{to: "/agent/verify-email"}}} = live(authed, ~p"/agent")
  end

  test "signup persists the application without a password", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/agent")

    view
    |> element("#agent-application-form")
    |> render_submit(%{"agent_application" => attrs()})

    assert render(view) =~ "Application received"

    application = Repo.get_by!(AgentApplication, email: "jane.login@example.com")
    assert application.status == "pending"
    assert is_nil(application.password_hash)
  end
end
