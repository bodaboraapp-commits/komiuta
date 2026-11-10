defmodule XpressbusWeb.AiTripBuilderTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the destination step with search and trending destinations", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/ai-trip-builder")

    assert html =~ "Find your dream destination"
    assert has_element?(view, "#destination-search-form")
    assert has_element?(view, "#destination-search")
    assert has_element?(view, "#destination-cox")
    assert has_element?(view, "#destination-rome")
    assert has_element?(view, "#destination-istanbul")
  end

  test "searching a destination continues to the date-range calendar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ai-trip-builder")

    view
    |> form("#destination-search-form", %{"query" => "Zanzibar"})
    |> render_submit()

    assert has_element?(view, "#step-dates")
    assert has_element?(view, "#date-range-label", "Please select a date range")
    assert has_element?(view, "#calendar-prev")
    assert has_element?(view, "#calendar-next")
    assert has_element?(view, "#dates-next[disabled]")
    assert render(view) =~ "Zanzibar"
  end

  test "a trending destination can be selected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ai-trip-builder")

    view |> element("#destination-bangkok") |> render_click()

    assert has_element?(view, "#step-dates")
    assert render(view) =~ "Bangkok"
  end

  test "the full wizard produces a trip brief", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ai-trip-builder")

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

    view
    |> form("#companions-form", %{"adults" => "2", "children" => "1"})
    |> render_submit()

    assert has_element?(view, "#step-budget")

    view
    |> form("#budget-form", %{"budget" => "KES 50,000 – 100,000"})
    |> render_submit()

    assert has_element?(view, "#step-preferences")

    view |> element("#preference-beach") |> render_click()
    view |> element("#preference-food") |> render_click()
    view |> element("#build-itinerary") |> render_click()

    assert has_element?(view, "#step-summary")
    html = render(view)
    assert html =~ "Cox"
    assert html =~ Calendar.strftime(start_date, "%d %b %Y")
    assert html =~ Calendar.strftime(end_date, "%d %b %Y")
    assert html =~ "2 adults · 1 child"
    assert html =~ "Beach · Food"
    assert has_element?(view, "#open-chyllz-ai")
    assert has_element?(view, "#browse-chyllz")
  end
end
