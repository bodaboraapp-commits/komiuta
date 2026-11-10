defmodule XpressbusWeb.DashboardChyllzTabTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures
  import Xpressbus.CatalogueFixtures

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  # A forecast shaped exactly like `Xpressbus.Weather.load/1` returns. The
  # override function echoes the searched city back so the test can prove the
  # search form drives the widget.
  @hourly [
    %{time: "2026-11-10T09:00", label: "09:00", temperature: 27},
    %{time: "2026-11-10T10:00", label: "10:00", temperature: 29},
    %{time: "2026-11-10T11:00", label: "11:00", temperature: 31},
    %{time: "2026-11-10T12:00", label: "12:00", temperature: 32},
    %{time: "2026-11-10T13:00", label: "13:00", temperature: 33},
    %{time: "2026-11-10T14:00", label: "14:00", temperature: 33},
    %{time: "2026-11-10T15:00", label: "15:00", temperature: 31}
  ]

  @daily [
    %{label: "Today", condition: "Partly cloudy", icon: :partly_cloudy, high: 33, low: 24},
    %{label: "Wed", condition: "Rain", icon: :rain, high: 30, low: 23},
    %{label: "Thu", condition: "Clear sky", icon: :clear, high: 34, low: 25}
  ]

  setup do
    forecast = %{
      location: %{name: "Nairobi", country: "Kenya"},
      temperature: 30,
      feels_like: 32,
      condition: "Partly cloudy",
      icon: :partly_cloudy,
      is_day: true,
      high: 33,
      low: 24,
      humidity: 51,
      wind: 12,
      hourly: @hourly,
      daily: @daily,
      timezone: "Africa/Nairobi",
      fetched_at: DateTime.utc_now()
    }

    Application.put_env(
      :xpressbus,
      :weather_forecast_override,
      fn query ->
        {:ok, %{forecast | location: %{name: to_string(query), country: "Kenya"}}}
      end
    )

    on_exit(fn -> Application.delete_env(:xpressbus, :weather_forecast_override) end)

    :ok
  end

  defp signed_in(conn, user) do
    Plug.Test.init_test_session(conn, %{user_id: user.id})
  end

  defp ticket_fixture(user, attrs) do
    defaults = %{
      ticket_id: "TKT-#{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Mombasa",
      travel_date: Date.utc_today(),
      departure: "7:00 AM",
      arrival: "1:30 PM",
      company: "MashPoa",
      price: "2300",
      seats: "[\"6\"]",
      passenger_name: user.name,
      passenger_phone: user.phone,
      payment_method: "mpesa",
      status: "confirmed",
      type: "One Way"
    }

    Repo.insert!(struct(Ticket, Map.merge(defaults, attrs)))
  end

  test "guests are redirected to the login page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/user/login"}}} =
             live(conn, ~p"/dashboard?tab=chyllz")
  end

  test "accounts without a complete profile finish their profile first", %{conn: conn} do
    user = user_fixture()
    {:ok, incomplete} = Repo.update(Ecto.Changeset.change(user, phone: nil))

    assert {:error, {:redirect, %{to: "/user/complete-profile"}}} =
             live(signed_in(conn, incomplete), ~p"/dashboard")
  end

  test "the account still opens on the My Bus tab by default", %{conn: conn} do
    user = user_fixture()

    {:ok, view, html} = live(signed_in(conn, user), ~p"/dashboard")

    assert html =~ "Active &amp; Past Bookings"
    assert has_element?(view, "#user-tab-bus")
    refute has_element?(view, "#chyllz-account")
  end

  test "the tab menu toggles between My Bus and My Chyllz", %{conn: conn} do
    user = user_fixture()
    ticket = ticket_fixture(user, %{})

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard")

    # My Bus shows the booking list.
    assert has_element?(view, "#user-tab-bus")
    refute has_element?(view, "#chyllz-account")

    # Clicking "My Chyllz" in the existing menu swaps in the Chyllz account view
    # and keeps the tab in the URL so a refresh reopens it.
    view |> element("#user-tab-chyllz") |> render_click()
    assert_patch(view, ~p"/dashboard?tab=chyllz")

    assert has_element?(view, "#chyllz-account")
    assert has_element?(view, "#chyllz-welcome")
    assert has_element?(view, "#trip-card-#{ticket.ticket_id}")

    # Clicking "My Bus" swaps back to the booking list.
    view |> element("#user-tab-bus") |> render_click()
    assert_patch(view, ~p"/dashboard")

    refute has_element?(view, "#chyllz-account")
    assert has_element?(view, "#user-tab-bus")
  end

  test "?tab=chyllz deep-links straight into the Chyllz account view", %{conn: conn} do
    user = user_fixture()
    future = Date.add(Date.utc_today(), 4)
    past = Date.add(Date.utc_today(), -8)

    upcoming = ticket_fixture(user, %{to: "Kisumu", travel_date: future, price: "1800"})
    completed = ticket_fixture(user, %{to: "Mombasa", travel_date: past, status: "completed"})

    {:ok, view, html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert html =~ "Welcome back,"
    assert has_element?(view, "#chyllz-welcome")
    assert has_element?(view, "#build-with-ai")
    assert has_element?(view, "#create-new-trip")
    assert has_element?(view, "#view-my-trips")

    assert has_element?(view, "#stat-total-trips-value", "2")
    assert has_element?(view, "#stat-upcoming-trips-value", "1")
    assert has_element?(view, "#stat-places-visited-value", "1")

    assert has_element?(view, "#recent-trips")
    assert has_element?(view, "#trip-card-#{upcoming.ticket_id}")
    assert has_element?(view, "#trip-card-#{completed.ticket_id}")
    assert has_element?(view, "#manage-itinerary-#{upcoming.ticket_id}", "Manage Itinerary")
    assert has_element?(view, "#preview-trip-#{upcoming.ticket_id}")
    assert has_element?(view, "#share-trip-#{upcoming.ticket_id}")

    # The eye button previews the itinerary in the existing ticket modal.
    view |> element("#preview-trip-#{upcoming.ticket_id}") |> render_click()
    assert has_element?(view, "#ticket-qr")
    view |> element("button[phx-click='close_ticket']", "close") |> render_click()
    refute has_element?(view, "#no-trips")

    assert has_element?(view, "#weather-card")
    assert has_element?(view, "#weather-current", "30°C")
    assert has_element?(view, "#weather-hourly")
    assert has_element?(view, "#weather-daily")

    assert has_element?(view, "#popular-destinations")
    assert has_element?(view, ".destination-chip")
  end

  test "the Chyllz tab shows an empty state without trips", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert has_element?(view, "#no-trips")
    assert has_element?(view, "#stat-total-trips-value", "0")
    # No catalogue fixtures in this test, so no suggestions are rendered.
    refute has_element?(view, "#chyllz-picks")
  end

  test "accounts without trips get Chyllz suggestions to fill the layout", %{conn: conn} do
    hotel = hotel_fixture(%{name: "Diani Beach House"})
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert has_element?(view, "#no-trips")
    assert has_element?(view, "#chyllz-picks")
    assert has_element?(view, "#chyllz-picks-heading", "Chyllz picks for you")
    assert has_element?(view, "#chyllz-pick-hotel-#{hotel.id}")
    assert has_element?(view, "#chyllz-stories")
    assert has_element?(view, "#chyllz-stories-heading", "Travel stories")
    assert has_element?(view, "#chyllz-story-nairobi-to-kisumu-bus-guide")
  end

  test "weather search updates the widget inside the tab", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert has_element?(view, "#weather-location", "Nairobi")

    html =
      view
      |> form("#weather-search-form", %{"city" => "Kisumu"})
      |> render_submit()

    assert html =~ "Kisumu"
    assert has_element?(view, "#weather-location", "Kisumu")
  end

  test "weather search rejects an empty city", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    html =
      view
      |> form("#weather-search-form", %{"city" => "   "})
      |> render_submit()

    assert html =~ "Type a city name to see its weather."
  end

  test "shows the weather fallback when the lookup has no source", %{conn: conn} do
    # Without the override the test config disables live weather, which is the
    # same path a production outage takes.
    Application.delete_env(:xpressbus, :weather_forecast_override)
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    assert has_element?(view, "#weather-unavailable")
    assert has_element?(view, "#weather-retry")
  end

  test "footer tabs still work next to the Chyllz account view", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard?tab=chyllz")

    html = render_click(view, "change_footer_tab", %{"tab" => "how"})
    assert html =~ "01. Search"
  end

  test "the account page is excluded from search indexes", %{conn: conn} do
    user = user_fixture()

    html =
      conn
      |> signed_in(user)
      |> get(~p"/dashboard?tab=chyllz")
      |> html_response(200)

    assert html =~ ~s(name="robots" content="noindex,nofollow")
  end
end
