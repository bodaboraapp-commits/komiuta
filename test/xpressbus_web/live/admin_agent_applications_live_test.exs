defmodule XpressbusWeb.AdminAgentApplicationsLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Agents

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  defp create_agent do
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

    application
  end

  test "lists agent applications and lets an admin approve one", %{conn: conn} do
    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Admin Agent",
        "business_name" => "Admin Travel",
        "email" => "admin.agent@example.com",
        "phone" => "0734567890",
        "city" => "Nairobi"
      })

    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/agent-applications")

    assert html =~ "Agent Applications"
    assert html =~ "Agent sign-ups"
    assert html =~ "Admin Travel"
    assert html =~ application.reference

    assert has_element?(view, "#application-#{application.id}")
    assert has_element?(view, "a[href='tel:0734567890']") == false
    assert html =~ "Submitted"

    toggle = "button[phx-click='toggle_application'][phx-value-id='#{application.id}']"
    assert has_element?(view, toggle)
    refute has_element?(view, "#application-actions-#{application.id}")

    view |> element(toggle) |> render_click()
    assert has_element?(view, "#application-actions-#{application.id}")
    assert has_element?(view, "a[href='tel:0734567890']")
    assert has_element?(view, "a[href='mailto:admin.agent@example.com']")
    assert render(view) =~ "Payout: M-Pesa"

    view
    |> element("button[phx-value-id='#{application.id}'][phx-value-status=approved]")
    |> render_click()

    assert Agents.get_application!(application.id).status == "approved"
    assert render(view) =~ "Application approved"
    assert render(view) =~ "Email: sent"
  end

  test "rejection requires a reason and sends it to the agent", %{conn: conn} do
    application = create_agent()
    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/agent-applications")

    view
    |> element("button[phx-click='toggle_application'][phx-value-id='#{application.id}']")
    |> render_click()

    view
    |> form("#reject-agent-#{application.id}", %{"reason" => ""})
    |> render_submit()

    assert Agents.get_application!(application.id).status == "pending"
    assert render(view) =~ "rejection reason is required"

    view
    |> form("#reject-agent-#{application.id}", %{
      "reason" => "Business registration missing"
    })
    |> render_submit()

    rejected = Agents.get_application!(application.id)
    assert rejected.status == "rejected"
    assert rejected.admin_notes == "Business registration missing"
    assert render(view) =~ "Business registration missing"
  end

  test "renders the application details and the M-Pesa payout label", %{conn: conn} do
    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Detail Agent",
        "business_name" => "Detail Travel",
        "email" => "detail.agent@example.com",
        "phone" => "0711000000",
        "city" => "Kisumu",
        "payout_method" => "mpesa",
        "routes" => "Kisumu - Nairobi",
        "notes" => "Two shuttles daily."
      })

    {:ok, _rejected} = Agents.update_status(application, "rejected", "Missing business permit")

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/agent-applications")

    assert has_element?(view, "#application-#{application.id}")
    refute has_element?(view, "#application-details-#{application.id}")

    toggle = "button[phx-click='toggle_application'][phx-value-id='#{application.id}']"
    view |> element(toggle) |> render_click()

    assert has_element?(view, "#application-details-#{application.id}")

    html = render(view)
    # Activity timeline: submission (with reference) and the review outcome.
    assert html =~ "Application submitted"
    assert html =~ "Ref #{application.reference}"
    assert html =~ "Application rejected"
    assert html =~ "Missing business permit"

    # Contact and application details are inside the expanded card.
    assert html =~ "Kisumu - Nairobi"
    assert html =~ "Two shuttles daily."
    assert html =~ "Payout: M-Pesa"

    # Clicking the summary again collapses the card for a compact list.
    view |> element(toggle) |> render_click()
    refute has_element?(view, "#application-details-#{application.id}")
  end

  test "redirects non-admin users", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} =
             live(conn, ~p"/admin/agent-applications")
  end
end
