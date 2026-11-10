defmodule XpressbusWeb.TripManageLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.{Itineraries, Repo, TripItinerary}
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

  test "budget and expenses persist after reloading the page", %{conn: conn} do
    user = user_fixture()
    ticket = ticket_fixture(user, %{})
    session = Plug.Test.init_test_session(conn, %{user_id: user.id})

    {:ok, view, _html} = live(session, ~p"/trips/#{ticket.ticket_id}/manage")

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

    {:ok, _reloaded, html} = live(session, ~p"/trips/#{ticket.ticket_id}/manage")

    assert html =~ "KES 850"
    assert html =~ "Lunch"
    assert html =~ "KES 25,000"
  end

  test "a saved AI itinerary uses the same management page and persists expenses", %{conn: conn} do
    user = user_fixture()
    today = Date.utc_today()

    trip = %{
      destination: "Diani Beach",
      country: "Kenya",
      start_date: Date.add(today, 2),
      end_date: Date.add(today, 4),
      travel_party: "couple",
      budget: "balanced",
      preferences: ["Beach Vacations"],
      latitude: 21.4272,
      longitude: 92.0058,
      place_source: :geocoding
    }

    {:ok, saved} = Itineraries.save(user, trip, TripItinerary.generate(trip))
    session = Plug.Test.init_test_session(conn, %{user_id: user.id})

    {:ok, view, html} = live(session, ~p"/trips/saved/#{saved.id}/manage")

    assert html =~ saved.title
    assert has_element?(view, "#trip-tab-expenses")

    view |> element("button", "+ Add Expense") |> render_click()

    view
    |> form("form[phx-submit='save_expense']", %{
      "expense" => %{"label" => "Boat ride", "category" => "Activities", "amount" => "2500"}
    })
    |> render_submit()

    {:ok, _reloaded, reloaded_html} = live(session, ~p"/trips/saved/#{saved.id}/manage")

    assert reloaded_html =~ "Boat ride"
    assert reloaded_html =~ "KES 2,500"
  end

  test "another user cannot open a saved itinerary management page", %{conn: conn} do
    owner = user_fixture()
    other = user_fixture()
    today = Date.utc_today()

    trip = %{
      destination: "Rome",
      country: "Italy",
      start_date: Date.add(today, 1),
      end_date: Date.add(today, 3),
      travel_party: "solo",
      budget: "luxury",
      preferences: [],
      latitude: 41.9028,
      longitude: 12.4964,
      place_source: :geocoding
    }

    {:ok, saved} = Itineraries.save(owner, trip, TripItinerary.generate(trip))

    session = Plug.Test.init_test_session(conn, %{user_id: other.id})

    assert {:error, {:redirect, %{to: "/dashboard?tab=chyllz"}}} =
             live(session, ~p"/trips/saved/#{saved.id}/manage")
  end
end
