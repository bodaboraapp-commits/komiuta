defmodule XpressbusWeb.AdminAgentBusOperatorTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Agents
  alias Xpressbus.BusOperators

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  test "an admin can tie an agent application to a bus operator", %{conn: conn} do
    {:ok, bus_operator} =
      BusOperators.create_bus_operator(%{name: "Metro Partner", active: true})

    {:ok, application} =
      Agents.create_application(%{
        "full_name" => "Assignable Agent",
        "business_name" => "Assignable Travel",
        "email" => "assignable.agent@example.com",
        "phone" => "0755667788",
        "city" => "Nairobi"
      })

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/agent-applications")

    view
    |> element("button[phx-click='toggle_application'][phx-value-id='#{application.id}']")
    |> render_click()

    assert has_element?(view, "#assign-bus-operator-#{application.id}")

    view
    |> form("#assign-bus-operator-#{application.id}", %{"bus_operator_id" => bus_operator.id})
    |> render_submit()

    assigned = Agents.get_application_with_bus_operator(application.id)
    assert assigned.bus_operator_id == bus_operator.id
    assert assigned.bus_operator.name == "Metro Partner"

    html = render(view)
    assert html =~ "Metro Partner"
  end

  test "bus operator table shows the assigned agent", %{conn: conn} do
    {:ok, bus_operator} =
      BusOperators.create_bus_operator(%{name: "Rift Partner", active: true})

    {:ok, _application} =
      Agents.create_application(%{
        "full_name" => "Shown Agent",
        "business_name" => "Shown Travel",
        "email" => "shown.agent@example.com",
        "phone" => "0766778899",
        "city" => "Nakuru",
        "bus_operator_id" => bus_operator.id
      })

    {:ok, _view, html} = live(admin_conn(conn), ~p"/admin/bus-operators")

    assert html =~ "Rift Partner"
    assert html =~ "Shown Agent"
    refute html =~ "Unassigned"
  end
end
