defmodule XpressbusWeb.AiTripBuilderSaveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.{Itineraries, TripItinerary}
  alias Xpressbus.Itineraries.SavedItinerary
  alias Xpressbus.Repo

  defp signed_in(conn, user) do
    Plug.Test.init_test_session(conn, %{user_id: user.id})
  end

  defp complete_wizard(view) do
    today = Date.utc_today()

    view |> element("#destination-cox") |> render_click()
    view |> element("#calendar-day-#{Date.to_iso8601(Date.add(today, 1))}") |> render_click()
    view |> element("#calendar-day-#{Date.to_iso8601(Date.add(today, 2))}") |> render_click()
    view |> element("#dates-next") |> render_click()
    view |> element("#companion-couple") |> render_click()
    view |> element("#companions-next") |> render_click()
    view |> element("#budget-luxury") |> render_click()
    view |> element("#budget-next") |> render_click()
    view |> element("#preference-beach-vacations") |> render_click()
    view |> element("#build-itinerary") |> render_click()
    send(view.pid, :trip_generated)

    view
  end

  test "a signed-in traveller can save an itinerary to My Chyllz", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/trip/build-with-ai")
    complete_wizard(view)

    assert has_element?(view, "#step-summary")

    view |> element("#save-itinerary") |> render_click()

    assert_redirect(view, "/dashboard?tab=chyllz")

    assert [saved] = Itineraries.list_for_user(user)
    assert saved.title =~ "Cox's Bazar"
    assert saved.start_date == Date.add(Date.utc_today(), 1)
    assert saved.preferences =~ "Beach Vacations"

    {:ok, dashboard, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert has_element?(dashboard, "#saved-itineraries")
    assert has_element?(dashboard, "#itinerary-card-#{saved.id}")
    assert has_element?(dashboard, "#manage-itinerary-#{saved.id}")
    assert has_element?(dashboard, "#itinerary-card-#{saved.id} h3", saved.title)
    assert has_element?(dashboard, "#itinerary-card-#{saved.id}", "Cox's Bazar, Bangladesh")

    assert has_element?(
             dashboard,
             "#itinerary-card-#{saved.id} a[href='/trip/build-with-ai?saved=#{saved.id}']"
           )
  end

  test "saving as a guest asks the traveller to sign in", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")
    complete_wizard(view)

    view |> element("#save-itinerary") |> render_click()

    assert render(view) =~ "Sign in to save"
    assert Repo.aggregate(SavedItinerary, :count, :id) == 0
  end

  test "a saved itinerary can be re-opened from the dashboard link", %{conn: conn} do
    user = user_fixture()

    today = Date.utc_today()

    trip = %{
      destination: "Cox's Bazar",
      country: "Bangladesh",
      start_date: Date.add(today, 1),
      end_date: Date.add(today, 2),
      travel_party: "couple",
      budget: "luxury",
      preferences: ["Beach Vacations"],
      latitude: 21.4272,
      longitude: 92.0058
    }

    {:ok, saved} = Itineraries.save(user, trip, TripItinerary.generate(trip))

    {:ok, reopened, _html} =
      live(signed_in(conn, user), ~p"/trip/build-with-ai?saved=#{saved.id}")

    assert has_element?(reopened, "#step-summary")
    assert has_element?(reopened, "#itinerary-title", saved.title)
    assert has_element?(reopened, "#itinerary-save-bar", "Saved")
  end

  test "the dashboard shows an empty state before the first saved itinerary", %{conn: conn} do
    user = user_fixture()

    {:ok, dashboard, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert has_element?(dashboard, "#saved-itineraries")
    assert has_element?(dashboard, "#no-saved-itineraries")
    assert has_element?(dashboard, "#start-ai-itinerary[href='/trip/build-with-ai']")
  end
end
