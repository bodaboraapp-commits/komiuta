defmodule XpressbusWeb.AdminAgentApplicationsLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Agents

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  test "lists agent applications and lets an admin approve one", %{conn: conn} do
    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Admin Agent",
        "business_name" => "Admin Travel",
        "email" => "admin.agent@example.com",
        "phone" => "0734567890",
        "city" => "Nairobi",
        "password" => "agentpass123",
        "password_confirmation" => "agentpass123"
      })

    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/agent-applications")

    assert html =~ "Agent Applications"
    assert html =~ "Agent sign-ups"
    assert html =~ "Admin Travel"
    assert html =~ application.reference

    view
    |> element("button[phx-value-id='#{application.id}'][phx-value-status=approved]")
    |> render_click()

    assert Agents.get_application!(application.id).status == "approved"
    assert render(view) =~ "Application approved"
  end

  test "redirects non-admin users", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} =
             live(conn, ~p"/admin/agent-applications")
  end
end
