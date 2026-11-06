defmodule XpressbusWeb.AgentGoogleAuthTest do
  use XpressbusWeb.ConnCase

  alias Xpressbus.Agents
  alias Xpressbus.Integrations
  alias XpressbusWeb.AuthController

  defp create_agent(overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          "full_name" => "Google Agent",
          "business_name" => "Google Travel",
          "email" => "google.agent@example.com",
          "phone" => "0711223344",
          "city" => "Nairobi",
          "payout_method" => "mpesa"
        },
        overrides
      )

    {:ok, application} = Agents.create_application(attrs)
    application
  end

  defp enable_google do
    {:ok, _config} =
      Integrations.upsert_config_by_provider("google", %{
        active: true,
        config: %{"client_id" => "test-client-id", "client_secret" => "test-secret"}
      })

    :ok
  end

  defp google_auth(email) do
    %Ueberauth.Auth{
      uid: "google-#{email}",
      provider: :google,
      info: %Ueberauth.Auth.Info{
        email: email,
        name: "Google Agent"
      }
    }
  end

  test "agent login is phone-first even when Google OAuth is configured", %{conn: conn} do
    enable_google()

    html = conn |> get("/agent/login") |> html_response(200)

    assert html =~ "Phone number"
    assert html =~ ~s(action="/agent/auth")
    refute html =~ "Continue with Google"
  end

  test "Google sign-in is hidden when Google OAuth is not configured", %{conn: conn} do
    html = conn |> get("/agent/login") |> html_response(200)

    refute html =~ "Continue with Google"
  end

  test "Google start marks the session and starts the OAuth request", %{conn: conn} do
    conn = get(conn, "/agent/google/start")

    assert redirected_to(conn) == "/auth/google"
    assert get_session(conn, :agent_google_pending) == true
  end

  test "Google callback hands off a signed agent session to the Agent origin", %{conn: conn} do
    application = create_agent()

    conn =
      conn
      |> Plug.Test.init_test_session(%{agent_google_pending: true})
      |> Plug.Conn.assign(:ueberauth_auth, google_auth(application.email))

    conn = AuthController.callback(conn, %{})

    location = redirected_to(conn)
    assert location =~ "https://agent.komiuta.com/agent/google/complete?token="
    refute get_session(conn, :agent_google_pending)

    token =
      location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("token")

    complete_conn =
      get(build_conn(), "/agent/google/complete?#{URI.encode_query(%{"token" => token})}")

    assert redirected_to(complete_conn) == "/agent/account"
    assert get_session(complete_conn, :agent_id) == application.id
  end

  test "Google callback without an agent application redirects to an explanation", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{agent_google_pending: true})
      |> Plug.Conn.assign(:ueberauth_auth, google_auth("not.an.agent@example.com"))

    conn = AuthController.callback(conn, %{})

    assert redirected_to(conn) =~ "/agent/login?"
    assert redirected_to(conn) =~ "google_error=no_agent"

    html = build_conn() |> get("/agent/login?google_error=no_agent") |> html_response(200)
    assert html =~ "No agent application was found for that Google email"
  end

  test "Google callback failure returns to agent login", %{conn: conn} do
    conn =
      conn
      |> Plug.Test.init_test_session(%{agent_google_pending: true})
      |> Plug.Conn.assign(:ueberauth_failure, %Ueberauth.Failure{errors: []})

    conn = AuthController.callback(conn, %{})

    assert redirected_to(conn) =~ "google_error=failed"
  end

  test "Google complete rejects an invalid token", %{conn: conn} do
    conn = get(conn, "/agent/google/complete?token=not-a-valid-token")

    assert redirected_to(conn) =~ "google_error=failed"
    refute get_session(conn, :agent_id)
  end
end
