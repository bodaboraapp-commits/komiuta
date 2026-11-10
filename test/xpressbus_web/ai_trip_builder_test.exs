defmodule XpressbusWeb.AiTripBuilderTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.GooglePlaces
  alias Xpressbus.Places

  setup do
    previous = Application.get_env(:xpressbus, :places_search_override)
    Places.reset_cache()

    Application.put_env(:xpressbus, :places_search_override, fn query ->
      case String.downcase(query) do
        "zanzibar" ->
          [
            %{
              name: "Zanzibar City",
              country: "Tanzania",
              region: "Zanzibar Urban/West",
              latitude: -6.1659,
              longitude: 39.2026
            }
          ]

        _other ->
          []
      end
    end)

    on_exit(fn ->
      Places.reset_cache()

      if previous == nil do
        Application.delete_env(:xpressbus, :places_search_override)
      else
        Application.put_env(:xpressbus, :places_search_override, previous)
      end
    end)

    :ok
  end

  test "renders the destination step with search and trending destinations", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/trip/build-with-ai")

    assert html =~ "Find your dream destination"
    assert has_element?(view, "#destination-search-form")
    assert has_element?(view, "#destination-search")
    assert has_element?(view, "#destination-cox")
    assert has_element?(view, "#destination-rome")
    assert has_element?(view, "#destination-istanbul")
  end

  test "searching a destination continues to the date-range calendar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view
    |> form("#destination-search-form", %{"query" => "Zanzibar"})
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#step-dates")
    assert has_element?(view, "#date-range-label", "Please select a date range")
    assert has_element?(view, "#calendar-prev")
    assert has_element?(view, "#calendar-next")
    assert has_element?(view, "#dates-next[disabled]")
    assert render(view) =~ "Zanzibar"
  end

  test "a trending destination can be selected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view |> element("#destination-bangkok") |> render_click()

    assert has_element?(view, "#step-dates")
    assert render(view) =~ "Bangkok"
  end

  test "the companions step offers travel-party cards and a pet toggle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")
    today = Date.utc_today()

    view |> element("#destination-rome") |> render_click()
    view |> element("#calendar-day-#{Date.to_iso8601(Date.add(today, 1))}") |> render_click()
    view |> element("#calendar-day-#{Date.to_iso8601(Date.add(today, 2))}") |> render_click()
    view |> element("#dates-next") |> render_click()

    assert has_element?(view, "#step-companions")
    assert has_element?(view, "#companion-solo")
    assert has_element?(view, "#companion-couple")
    assert has_element?(view, "#companion-family")
    assert has_element?(view, "#companion-friends")
    assert has_element?(view, "#companions-next[disabled]")

    view |> element("#companion-couple") |> render_click()
    refute has_element?(view, "#companions-next[disabled]")

    view |> element("#pets-yes") |> render_click()
    assert has_element?(view, "#pets-yes[aria-pressed='true']")

    view |> element("#companions-next") |> render_click()
    assert has_element?(view, "#step-budget")
  end

  test "the full wizard produces a trip brief", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    today = Date.utc_today()
    start_date = Date.add(today, 1)
    end_date = Date.add(today, 3)

    view |> element("#destination-cox") |> render_click()
    assert has_element?(view, "#step-dates")

    view |> element("#calendar-day-#{Date.to_iso8601(start_date)}") |> render_click()
    view |> element("#calendar-day-#{Date.to_iso8601(end_date)}") |> render_click()

    days = Date.diff(end_date, start_date) + 1

    assert has_element?(
             view,
             "#date-range-label",
             "Selected: #{Date.to_iso8601(start_date)} to #{Date.to_iso8601(end_date)} (#{days} Days)"
           )

    assert has_element?(view, "#date-range-summary")
    assert has_element?(view, "#estimated-credits", "#{days * 20} Credits")
    assert has_element?(view, "#credit-balance", "2.00 Credits")
    refute has_element?(view, "#dates-next[disabled]")

    view |> element("#dates-next") |> render_click()
    assert has_element?(view, "#step-companions")

    view |> element("#companion-friends") |> render_click()
    view |> element("#pets-no") |> render_click()
    view |> element("#companions-next") |> render_click()

    assert has_element?(view, "#step-budget")
    assert has_element?(view, "#budget-cheap")
    assert has_element?(view, "#budget-balanced")
    assert has_element?(view, "#budget-luxury")
    assert has_element?(view, "#budget-flexible")
    assert has_element?(view, "#budget-custom")
    assert has_element?(view, "#budget-mars")
    assert has_element?(view, "#budget-next[disabled]")

    view |> element("#budget-balanced") |> render_click()
    refute has_element?(view, "#budget-next[disabled]")
    view |> element("#budget-next") |> render_click()

    assert has_element?(view, "#step-preferences")
    assert has_element?(view, "#preference-adventure-travel")
    assert has_element?(view, "#preference-beach-vacations")
    assert has_element?(view, "#preference-food-tourism")
    assert has_element?(view, "#preference-cultural-exploration")

    view |> element("#preference-beach-vacations") |> render_click()
    view |> element("#preference-food-tourism") |> render_click()
    view |> element("#build-itinerary") |> render_click()

    assert has_element?(view, "#trip-generating")
    assert render(view) =~ "Generating Your Trip"
    assert render(view) =~ "Getting to know your"

    send(view.pid, :generation_tick)
    assert render(view) =~ "Hand-picking stays"

    send(view.pid, :generation_tick)
    assert render(view) =~ "Finding tables worth travelling for"

    send(view.pid, :trip_generated)

    assert has_element?(view, "#step-summary")
    assert has_element?(view, "#trip-itinerary")
    assert has_element?(view, "#itinerary-map")
    assert has_element?(view, "#itinerary-hotels")
    assert has_element?(view, "#itinerary-restaurants")
    assert has_element?(view, "#itinerary-map-frame[src*='output=embed']")
    assert has_element?(view, "#trip-itinerary #itinerary-save-bar #save-itinerary")
    html = render(view)
    assert html =~ "Cox"
    assert html =~ "Hotel Recommendation"
    assert html =~ "Hotels &amp; Stays"
    assert html =~ "Food"
    assert html =~ "Recommended Restaurants"
    assert html =~ "Classic Rice Table Dine"
    refute html =~ "View on Google Maps"
    assert html =~ "Important Notes"
    assert html =~ "friends"
    assert html =~ "Balanced"
    assert has_element?(view, "#open-chyllz-ai")
    assert has_element?(view, "#browse-chyllz")
  end

  test "google places is disabled during tests and falls back safely" do
    assert {:error, :not_configured} = GooglePlaces.recommendations("Moscow", :hotels)
    assert GooglePlaces.static_map("Moscow") == nil
  end
end
