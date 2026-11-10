defmodule XpressbusWeb.AiTripBuilderSearchTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Xpressbus.Places

  setup do
    previous = Application.get_env(:xpressbus, :places_search_override)
    Places.reset_cache()

    Application.put_env(:xpressbus, :places_search_override, fn query ->
      case String.downcase(query) do
        "par" ->
          [
            %{
              name: "Paris",
              country: "France",
              region: "Île-de-France",
              latitude: 48.8566,
              longitude: 2.3522
            },
            %{
              name: "Paro",
              country: "Bhutan",
              region: "Paro",
              latitude: 27.4287,
              longitude: 89.4167
            }
          ]

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

    Application.put_env(:xpressbus, :places_landmark_override, fn _query -> {:ok, []} end)

    on_exit(fn ->
      Places.reset_cache()
      Application.delete_env(:xpressbus, :places_landmark_override)

      if previous == nil do
        Application.delete_env(:xpressbus, :places_search_override)
      else
        Application.put_env(:xpressbus, :places_search_override, previous)
      end
    end)

    :ok
  end

  test "typing shows suggestions from real geocoded places", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view
    |> form("#destination-search-form", %{"query" => "par"})
    |> render_change()

    html = render_async(view)

    assert has_element?(view, "#destination-search-results")
    assert has_element?(view, "#destination-suggestion-0")
    assert has_element?(view, "#destination-suggestion-0", "Paris")
    assert html =~ "Paris, Île-de-France, France"
    assert html =~ "Paro"
  end

  test "choosing a suggestion continues with the verified place", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view
    |> form("#destination-search-form", %{"query" => "par"})
    |> render_change()

    render_async(view)

    view |> element("#destination-suggestion-0") |> render_click()

    assert has_element?(view, "#step-dates")
    assert render(view) =~ "Paris"
    assert render(view) =~ "France"
  end

  test "an unknown destination is rejected instead of accepted as free text", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view
    |> form("#destination-search-form", %{"query" => "nowhere"})
    |> render_change()

    render_async(view)

    assert has_element?(view, "#destination-search-empty")

    view
    |> form("#destination-search-form", %{"query" => "nowhere"})
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#builder-error")
    refute has_element?(view, "#step-dates")
  end

  test "submitting an exact real place continues without extra typing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view
    |> form("#destination-search-form", %{"query" => "zanzibar"})
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#step-dates")
    assert render(view) =~ "Zanzibar"
  end

  test "trending destinations still carry real coordinates", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view |> element("#destination-rome") |> render_click()

    assert has_element?(view, "#step-dates")
    assert render(view) =~ "Rome"
    assert render(view) =~ "Italy"
  end
end
