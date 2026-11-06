defmodule XpressbusWeb.AgentPwaTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Xpressbus.Agents
  alias Xpressbus.Repo

  test "agent app exposes the sign-up experience and Agent PWA manifest", %{conn: conn} do
    html = conn |> get(~p"/agent") |> html_response(200)

    assert html =~ "Komiuta Agent"
    assert html =~ "Create your agent account"
    assert html =~ "agent-application-form"
    assert html =~ "agent-install-button"
    assert html =~ ~s(href="/agent-manifest.json")
    assert html =~ "Submit Agent Application"
    assert html =~ "Log in"
    refute html =~ "api.qrserver.com"
    refute html =~ "Track Ticket"
  end

  test "website /agent redirects to the separate Agent origin", %{conn: conn} do
    conn = %{conn | host: "www.komiuta.com"}

    conn = conn |> get(~p"/agent")

    assert redirected_to(conn, 302) == "https://agent.komiuta.com/agent"
  end

  test "Agent subdomain root opens the Agent app", %{conn: conn} do
    conn = %{conn | host: "agent.komiuta.com"}

    conn = conn |> get(~p"/")

    assert redirected_to(conn, 302) == "https://agent.komiuta.com/agent"
  end

  test "Agent page canonical and QR use the Agent origin on the Agent subdomain", %{conn: conn} do
    conn = %{conn | host: "agent.komiuta.com"}
    html = conn |> get(~p"/agent") |> html_response(200)

    assert html =~ ~s(rel="canonical" href="https://agent.komiuta.com/agent")
    assert html =~ "https://agent.komiuta.com/agent"
  end

  test "agent can submit a sign-up application from the Agent PWA", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/agent")

    view
    |> element("#agent-application-form")
    |> render_submit(%{
      "agent_application" => %{
        "full_name" => "Jane Agent",
        "business_name" => "Jane Travel Agency",
        "email" => "jane.agent@example.com",
        "phone" => "0712345678",
        "city" => "Nairobi",
        "routes" => "Nairobi - Mombasa",
        "payout_method" => "mpesa",
        "notes" => "We serve the CBD.",
        "password" => "agentpass123",
        "password_confirmation" => "agentpass123"
      }
    })

    assert render(view) =~ "Application received"
    assert render(view) =~ "Jane Travel Agency"

    application = Repo.get_by!(Xpressbus.Agents.AgentApplication, email: "jane.agent@example.com")
    assert application.status == "pending"
    assert application.reference =~ "AGT-"
    assert application.password_hash
    refute application.password_hash == "agentpass123"

    assert_email_sent(fn email ->
      assert email.subject =~ "received your Komiuta Agent application"
      assert email.to == [{"Jane Agent", "jane.agent@example.com"}]
    end)
  end

  test "agent app validates missing sign-up fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/agent")

    view
    |> element("#agent-application-form")
    |> render_submit(%{"agent_application" => %{"full_name" => "Incomplete"}})

    assert render(view) =~ "Please check the highlighted details"
    assert Agents.list_applications() == []
  end

  test "agent manifest is installable and uses the existing app icons", %{conn: conn} do
    manifest =
      conn
      |> get(~p"/agent-manifest.json")
      |> response(200)
      |> Jason.decode!()

    assert manifest["id"] == "/agent"
    assert manifest["name"] == "KOMIUTA Agent"
    assert manifest["short_name"] == "KOMIUTA Agent"
    assert manifest["start_url"] == "/agent"
    assert manifest["scope"] == "/agent"
    assert manifest["display"] == "standalone"
    assert manifest["background_color"] == "#ffffff"
    assert manifest["theme_color"] == "#ffffff"

    assert Enum.any?(manifest["icons"], &(&1["src"] == "/images/agent-icon-192.png"))

    for icon <- manifest["icons"] do
      assert File.exists?(Path.join(["priv", "static", String.trim_leading(icon["src"], "/")]))
    end
  end
end
