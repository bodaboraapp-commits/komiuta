defmodule XpressbusWeb.SearchReturnTripTest do
  @moduledoc """
  The landing search pill has an "+ Add Return" affordance. Adding a return
  date turns the search into a round trip: a second date field appears, the
  return date is carried in the results URL, and the results page shows the
  return date. Removing it goes back to a one-way search.
  """

  use XpressbusWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  @travel_date "2026-12-01"
  @return_date "2026-12-08"

  defp fill_search_form(view, attrs) do
    defaults = %{"from" => "Nairobi", "to" => "Mombasa", "date" => @travel_date}
    form(view, "#search-form", Map.merge(defaults, attrs))
  end

  defp search_url(return_date \\ nil) do
    params = %{
      "fromCityName" => "Nairobi",
      "toCityName" => "Mombasa",
      "onward" => @travel_date
    }

    params = if return_date, do: Map.put(params, "return", return_date), else: params

    "/buses/Nairobi-to-Mombasa?" <> URI.encode_query(params)
  end

  test "the search pill shows an Add Return button and no return date by default", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#add-return-button")
    refute has_element?(view, "#return-date-field")
    refute has_element?(view, "#search-return-date")
  end

  test "Add Return reveals a return date field, and remove hides it again", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view |> element("#add-return-button") |> render_click()

    assert has_element?(view, "#return-date-field")
    assert has_element?(view, "#search-return-date")
    assert has_element?(view, "#remove-return-button")

    default_return = Date.to_string(Date.add(Date.utc_today(), 7))
    assert render(view) =~ default_return

    view |> element("#remove-return-button") |> render_click()

    refute has_element?(view, "#return-date-field")
    assert has_element?(view, "#add-return-button")
  end

  test "submitting a round trip carries the return date in the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view |> element("#add-return-button") |> render_click()

    view
    |> fill_search_form(%{"return_date" => @return_date})
    |> render_submit()

    assert_redirect(view, search_url(@return_date))
  end

  test "submitting a one-way search does not add a return parameter", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view |> fill_search_form(%{}) |> render_submit()

    assert_redirect(view, search_url())
  end

  test "the results page shows the return date for a round trip", %{conn: conn} do
    {:ok, view, _html} = live(conn, search_url(@return_date))

    assert has_element?(view, "#round-trip-badge")
    assert render(view) =~ @return_date
  end

  test "the results page has no round trip badge for a one-way search", %{conn: conn} do
    {:ok, view, _html} = live(conn, search_url())

    refute has_element?(view, "#round-trip-badge")
  end

  test "MODIFY returns to the search pill with the round trip kept", %{conn: conn} do
    {:ok, view, _html} = live(conn, search_url(@return_date))

    view |> element("#modify-search-button") |> render_click()

    expected =
      "/?" <>
        URI.encode_query(%{
          "from" => "Nairobi",
          "to" => "Mombasa",
          "date" => @travel_date,
          "return_date" => @return_date
        })

    assert_redirect(view, expected)
  end

  test "the landing page prefills the return date from query parameters", %{conn: conn} do
    path =
      "/?" <>
        URI.encode_query(%{
          "from" => "Nairobi",
          "to" => "Mombasa",
          "date" => @travel_date,
          "return_date" => @return_date
        })

    {:ok, view, _html} = live(conn, path)

    assert has_element?(view, "#return-date-field")
    assert has_element?(view, "#search-return-date")

    html = render(view)
    assert html =~ "Nairobi"
    assert html =~ "Mombasa"
    assert html =~ @return_date
  end
end
