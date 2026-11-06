defmodule XpressbusWeb.AgentAuthTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Agents
  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.Repo

  defp signup_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "full_name" => "Jane Agent",
        "business_name" => "Jane Travel",
        "email" => "jane.login@example.com",
        "phone" => "0712345678",
        "city" => "Nairobi",
        "payout_method" => "mpesa",
        "password" => "agentpass123",
        "password_confirmation" => "agentpass123"
      },
      overrides
    )
  end

  defp legacy_application do
    %AgentApplication{}
    |> AgentApplication.changeset(%{
      "reference" => "AGT-LEGACY1",
      "full_name" => "Legacy Agent",
      "business_name" => "Legacy Travel",
      "email" => "legacy.agent@example.com",
      "phone" => "0722000111",
      "city" => "Mombasa",
      "status" => "approved"
    })
    |> Repo.insert!()
  end

  test "agent login page is available", %{conn: conn} do
    html = conn |> get("/agent/login") |> html_response(200)

    assert html =~ "Agent log in"
    assert html =~ "Email or phone"
    assert html =~ "Create an agent account"
  end

  test "signup stores a hashed password and the agent can log in", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/agent")

    view
    |> element("#agent-application-form")
    |> render_submit(%{"agent_application" => signup_attrs()})

    application = Repo.get_by!(AgentApplication, email: "jane.login@example.com")
    assert application.password_hash
    refute application.password_hash == "agentpass123"
    assert render(view) =~ "Application received"

    login_conn =
      post(recycle(conn), "/agent/authenticate", %{
        "agent" => %{"identifier" => "jane.login@example.com", "password" => "agentpass123"}
      })

    assert redirected_to(login_conn) == "/agent/account"
    assert get_session(login_conn, :agent_id) == application.id

    account_conn = Plug.Test.init_test_session(build_conn(), %{agent_id: application.id})
    html = account_conn |> get("/agent/account") |> html_response(200)

    assert html =~ "Jane Travel"
    assert html =~ application.reference
    assert html =~ "pending"
  end

  test "wrong password is rejected", %{conn: conn} do
    {:ok, _application} = Agents.create_application(signup_attrs())

    conn =
      post(recycle(conn), "/agent/authenticate", %{
        "agent" => %{"identifier" => "jane.login@example.com", "password" => "wrong-password"}
      })

    assert html_response(conn, 200) =~ "Invalid email/phone or password"
    refute get_session(conn, :agent_id)
  end

  test "account and logout require/clear the session", %{conn: conn} do
    conn = get(recycle(conn), "/agent/account")
    assert redirected_to(conn) == "/agent/login"

    {:ok, application} = Agents.create_application(signup_attrs())

    authed = Plug.Test.init_test_session(build_conn(), %{agent_id: application.id})
    html = authed |> get("/agent/account") |> html_response(200)
    assert html =~ application.business_name

    logged_out = authed |> get("/agent/logout")
    assert redirected_to(logged_out) == "/agent/login"
    refute get_session(logged_out, :agent_id)
  end

  test "logged-in agents are sent from the signup page to their account" do
    {:ok, application} = Agents.create_application(signup_attrs())

    authed = Plug.Test.init_test_session(build_conn(), %{agent_id: application.id})

    assert {:error, {:redirect, %{to: "/agent/account"}}} = live(authed, "/agent")
  end

  test "legacy applications can activate a password with their reference", %{conn: conn} do
    application = legacy_application()
    refute application.password_hash

    conn =
      post(recycle(conn), "/agent/set-password", %{
        "agent" => %{
          "identifier" => "legacy.agent@example.com",
          "reference" => "AGT-LEGACY1",
          "password" => "newagentpass",
          "password_confirmation" => "newagentpass"
        }
      })

    assert redirected_to(conn) == "/agent/login"
    assert Repo.get!(AgentApplication, application.id).password_hash

    login_conn =
      post(recycle(conn), "/agent/authenticate", %{
        "agent" => %{"identifier" => "legacy.agent@example.com", "password" => "newagentpass"}
      })

    assert redirected_to(login_conn) == "/agent/account"
    assert get_session(login_conn, :agent_id) == application.id
  end

  test "activation rejects a wrong reference", %{conn: conn} do
    _application = legacy_application()

    conn =
      post(recycle(conn), "/agent/set-password", %{
        "agent" => %{
          "identifier" => "legacy.agent@example.com",
          "reference" => "AGT-WRONG",
          "password" => "newagentpass",
          "password_confirmation" => "newagentpass"
        }
      })

    assert html_response(conn, 200) =~ "could not match"
  end

  test "duplicate email signups are rejected and not persisted", %{conn: conn} do
    {:ok, _application} = Agents.create_application(signup_attrs())

    {:ok, view, _html} = live(conn, ~p"/agent")

    view
    |> element("#agent-application-form")
    |> render_submit(%{
      "agent_application" =>
        signup_attrs(%{"phone" => "0799999999", "full_name" => "Duplicate Agent"})
    })

    assert render(view) =~ "Please check the highlighted details"
    assert length(Agents.list_applications()) == 1
  end
end
