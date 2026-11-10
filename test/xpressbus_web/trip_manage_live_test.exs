defmodule XpressbusWeb.TripManageLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  defp ticket_fixture(user, attrs) do
    defaults = %{
      ticket_id: "TRIP-#{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Kisumu",
      travel_date: Date.add(Date.utc_today(), 3),
      departure: "7:00 AM",
      arrival: "4:00 PM",
      company: "Easy Coach",
      price: "1800",
      seats: "[\"12\"]",
      passenger_name: user.name,
      passenger_phone: user.phone,
      payment_method: "mpesa",
      status: "confirmed",
      type: "One Way"
    }

    Repo.insert!(struct(Ticket, Map.merge(defaults, attrs)))
  end

  test "signed-in passenger sees the KOMIUTA manage itinerary page", %{conn: conn} do
    user = user_fixture()
    ticket = ticket_fixture(user, %{})

    conn = Plug.Test.init_test_session(conn, %{user_id: user.id})
    {:ok, view, html} = live(conn, ~p"/trips/#{ticket.ticket_id}/manage")

    assert html =~ "All Expenses"
    assert html =~ "Nairobi → Kisumu"
    assert has_element?(view, "#trip-tab-expenses")
    assert has_element?(view, "#trip-tab-meals")
    assert has_element?(view, "#trip-tab-summary")
  end

  test "a passenger can add a budget and an expense", %{conn: conn} do
    user = user_fixture()
    ticket = ticket_fixture(user, %{})
    conn = Plug.Test.init_test_session(conn, %{user_id: user.id})
    {:ok, view, _html} = live(conn, ~p"/trips/#{ticket.ticket_id}/manage")

    view |> element("button", "Add Trip Budget") |> render_click()

    view
    |> form("form[phx-submit='save_budget']", %{"budget" => %{"amount" => "25000"}})
    |> render_submit()

    view |> element("button", "+ Add Expense") |> render_click()

    view
    |> form("form[phx-submit='save_expense']", %{
      "expense" => %{"label" => "Lunch", "category" => "Food", "amount" => "850"}
    })
    |> render_submit()

    html = render(view)
    assert html =~ "KES 850"
    assert html =~ "Lunch"
    assert html =~ "KES 25,000"
  end

  test "other users cannot manage someone else's trip", %{conn: conn} do
    owner = user_fixture()
    other = user_fixture(%{phone: "0798765432"})
    ticket = ticket_fixture(owner, %{})

    conn = Plug.Test.init_test_session(conn, %{user_id: other.id})

    assert {:error, {:redirect, %{to: "/dashboard"}}} =
             live(conn, ~p"/trips/#{ticket.ticket_id}/manage")
  end
end
