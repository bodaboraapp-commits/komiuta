defmodule XpressbusWeb.AgentDashboardTest do
  use XpressbusWeb.ConnCase

  alias Xpressbus.Agents
  alias Xpressbus.BusOperators

  defp create_agent(status \\ "pending", verified? \\ true) do
    {:ok, operator} =
      BusOperators.create_bus_operator(%{name: "Dash Partner", active: true})

    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Dash Agent",
        "business_name" => "Dash Travel",
        "email" => "dash.agent@example.com",
        "phone" => "0712345999",
        "city" => "Nairobi"
      })

    {:ok, application} = Agents.assign_bus_operator(application, operator.id)

    application =
      if verified? do
        {:ok, verified_application} =
          Agents.mark_email_verified(application, "dash.agent@example.com")

        verified_application
      else
        application
      end

    if status == "approved" do
      {:ok, approved_application} = Agents.update_status(application, "approved")
      approved_application
    else
      application
    end
  end

  test "approved, verified agents land on the dashboard", %{conn: conn} do
    agent = create_agent("approved", true)

    conn =
      Plug.Test.init_test_session(conn, %{agent_id: agent.id})

    html = conn |> get("/agent/dashboard") |> html_response(200)

    assert html =~ "Agent dashboard"
    assert html =~ ~r/Good (Morning|Afternoon|Evening), Dash/
    assert html =~ "Dash Agent"
    assert html =~ "Dash Travel"
    assert html =~ "Dash Partner"
    assert html =~ "Linked partner"
    assert html =~ "Bookings"
  end

  test "login sends approved agents to the dashboard", %{conn: conn} do
    agent = create_agent("approved", true)
    conn = Plug.Test.init_test_session(conn, %{agent_id: agent.id})

    conn = get(conn, "/agent/login")

    assert redirected_to(conn) == "/agent/dashboard"
  end

  test "pending agents are sent back to their account status page", %{conn: conn} do
    agent = create_agent("pending", true)
    conn = Plug.Test.init_test_session(conn, %{agent_id: agent.id})

    conn = get(conn, "/agent/dashboard")

    assert redirected_to(conn) == "/agent/account"
  end

  test "unverified pending agents must verify email", %{conn: conn} do
    agent = create_agent("pending", false)
    conn = Plug.Test.init_test_session(conn, %{agent_id: agent.id})

    conn = get(conn, "/agent/dashboard")

    assert redirected_to(conn) == "/agent/verify-email"
  end
end
