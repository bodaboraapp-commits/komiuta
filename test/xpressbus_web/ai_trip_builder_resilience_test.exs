defmodule XpressbusWeb.AiTripBuilderResilienceTest do
  use XpressbusWeb.ConnCase

  @moduletag capture_log: true

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  alias Xpressbus.Places

  setup do
    previous = Application.get_env(:xpressbus, :places_search_override)
    Places.reset_cache()

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

  test "a destination search network failure offers a retry instead of 'no matches'", %{
    conn: conn
  } do
    Application.put_env(:xpressbus, :places_search_override, fn _query ->
      raise "network down"
    end)

    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view
    |> form("#destination-search-form", %{"query" => "paris"})
    |> render_change()

    capture_log(fn -> render_async(view) end)

    assert has_element?(view, "#destination-search-error")
    assert has_element?(view, "#retry-destination-search")
    refute has_element?(view, "#destination-search-empty")
  end

  test "a transient search failure can be retried with the same query", %{conn: conn} do
    calls = :counters.new(1, [:atomics])
    previous = Application.get_env(:xpressbus, :places_search_override)
    Places.reset_cache()

    Application.put_env(:xpressbus, :places_search_override, fn _query ->
      :counters.add(calls, 1, 1)

      if :counters.get(calls, 1) == 1 do
        raise "temporary network failure"
      else
        [
          %{
            name: "Paris",
            country: "France",
            region: "Ile-de-France",
            latitude: 48.8566,
            longitude: 2.3522
          }
        ]
      end
    end)

    on_exit(fn ->
      Places.reset_cache()
      Application.put_env(:xpressbus, :places_search_override, previous)
    end)

    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    view
    |> form("#destination-search-form", %{"query" => "paris"})
    |> render_change()

    capture_log(fn -> render_async(view) end)
    assert has_element?(view, "#destination-search-error")

    view |> element("#retry-destination-search") |> render_click()
    render_async(view)

    assert has_element?(view, "#step-dates")
    assert render(view) =~ "Paris"
    refute has_element?(view, "#destination-search-error")
  end

  test "the generation screen exposes offline and slow-network feedback", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    reach_generation_step(view)

    html = render(view)
    assert has_element?(view, "#builder-network-banner")
    assert html =~ "NetworkStatus"
    assert has_element?(view, "#build-itinerary")
    assert html =~ "OfflineGuard"

    view |> element("#build-itinerary") |> render_click()

    assert has_element?(view, "#trip-generating")
    html = render(view)
    assert has_element?(view, "#generation-network-banner")
    assert html =~ "NetworkStatus"
    assert has_element?(view, "#generation-slow")
    assert html =~ "GenerationSlow"
  end

  test "curated recommendations are labelled and can be retried, and the map can reload", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    reach_generation_step(view)
    view |> element("#build-itinerary") |> render_click()

    # Tests run without Google Places credentials, so generation uses curated
    # picks; finish it immediately instead of waiting for the deadline.
    send(view.pid, :trip_generated)

    assert has_element?(view, "#step-summary")
    assert has_element?(view, "#recommendations-fallback")
    assert has_element?(view, "#retry-recommendations")
    assert has_element?(view, "#itinerary-map")
    assert render(view) =~ "ItineraryMap"
    assert has_element?(view, "#retry-map")

    view |> element("#retry-recommendations") |> render_click()
    render_async(view)

    assert has_element?(view, "#recommendations-fallback")
    assert has_element?(view, "#recommendations-status")
  end

  test "a failed generation exposes a retry action", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trip/build-with-ai")

    reach_generation_step(view)
    view |> element("#build-itinerary") |> render_click()

    ref = make_ref()

    :sys.replace_state(view.pid, fn state ->
      socket = state.socket
      assigns = %{socket.assigns | generation_ref: ref, generation_pid: self()}
      %{state | socket: %{socket | assigns: assigns}}
    end)

    send(view.pid, {:DOWN, ref, :process, self(), :boom})
    render(view)

    assert has_element?(view, "#generation-failed")
    assert has_element?(view, "#retry-generation")

    view |> element("#retry-generation") |> render_click()
    assert has_element?(view, "#trip-generating")
  end

  defp reach_generation_step(view) do
    today = Date.utc_today()
    start_date = Date.add(today, 1)
    end_date = Date.add(today, 3)

    view |> element("#destination-rome") |> render_click()
    view |> element("#calendar-day-#{Date.to_iso8601(start_date)}") |> render_click()
    view |> element("#calendar-day-#{Date.to_iso8601(end_date)}") |> render_click()
    view |> element("#dates-next") |> render_click()
    view |> element("#companion-couple") |> render_click()
    view |> element("#companions-next") |> render_click()
    view |> element("#budget-balanced") |> render_click()
    view |> element("#budget-next") |> render_click()
    view |> element("#preference-beach-vacations") |> render_click()
    assert has_element?(view, "#build-itinerary")
  end
end
