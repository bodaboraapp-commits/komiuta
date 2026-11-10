defmodule XpressbusWeb.AdminCarHireLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.CarHires

  defp admin_conn(conn), do: Plug.Test.init_test_session(conn, %{admin_id: 1})

  test "redirects non-admin users", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, ~p"/admin/car-hires")
  end

  test "manager can add, edit, toggle and delete a vehicle", %{conn: conn} do
    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/car-hires")

    assert html =~ "Premium vehicles"
    assert has_element?(view, "#add-car-hire-button")
    refute has_element?(view, "#car-hire-form")

    view |> element("#add-car-hire-button") |> render_click()

    view
    |> form("#car-hire-form", %{
      "car_name" => "Nissan Patrol",
      "type" => "4x4 Safari",
      "location" => "Mombasa",
      "price_per_day" => "16000",
      "active" => "true"
    })
    |> render_submit()

    car = CarHires.list_car_hires() |> Enum.find(&(&1.car_name == "Nissan Patrol"))
    assert car
    assert render(view) =~ "Nissan Patrol"

    view
    |> element("button[phx-click='edit_car'][phx-value-id='#{car.id}']")
    |> render_click()

    view
    |> form("#car-hire-form", %{"car_name" => "Nissan Patrol Elite", "active" => "true"})
    |> render_submit()

    assert Enum.any?(CarHires.list_car_hires(), &(&1.car_name == "Nissan Patrol Elite"))

    car = CarHires.get_car_hire!(car.id)

    view
    |> element("button[phx-click='toggle_active'][phx-value-id='#{car.id}']")
    |> render_click()

    refute CarHires.get_car_hire!(car.id).active

    view
    |> element("button[phx-click='delete_car'][phx-value-id='#{car.id}']")
    |> render_click()

    assert is_nil(CarHires.get_car_hire(car.id))
  end

  test "search filters the manager table", %{conn: conn} do
    {:ok, _} =
      CarHires.create_car_hire(%{
        "car_name" => "Range Rover",
        "type" => "Luxury SUV",
        "location" => "Mombasa",
        "price_per_day" => "35000"
      })

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/car-hires")

    assert view |> form("#car-hire-search-form", %{"search_query" => "range"}) |> render_change() =~
             "Range Rover"
  end
end
