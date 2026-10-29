defmodule XpressbusWeb.ChyllzLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.CatalogueFixtures

  describe "overview page" do
    test "renders every collection from the database", %{conn: conn} do
      hotel = hotel_fixture(%{name: "Overview Hotel Test"})
      gem = hidden_gem_fixture(%{title: "Overview Gem Test"})
      car = car_hire_fixture(%{car_name: "Overview Car Test"})
      event = event_fixture(%{title: "Overview Event Test"})

      {:ok, view, html} = live(conn, ~p"/tour-packages")

      assert html =~ "Find Your Perfect Stay with Chyllz"
      assert has_element?(view, "#chyllz-catalogue-counts")
      assert has_element?(view, "#hotel-card-#{hotel.id}")
      assert has_element?(view, "#gem-card-#{gem.id}")
      assert has_element?(view, "#car-card-#{car.id}")
      assert has_element?(view, "#event-card-#{event.id}")
    end

    test "links each collection to its dedicated page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tour-packages")

      assert has_element?(view, "a[href='/tour-packages/hotels']")
      assert has_element?(view, "a[href='/our-packages/hidden-gems']")
      assert has_element?(view, "a[href='/tour-packages/car']")
      assert has_element?(view, "a[href='/tour-packages/events']")
    end
  end

  describe "hotel collection" do
    test "renders active hotels and hides inactive ones", %{conn: conn} do
      shown = hotel_fixture(%{name: "Visible Hotel Test"})
      hidden = hotel_fixture(%{name: "Hidden Hotel Test", active: false})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/hotels")

      assert has_element?(view, "#hotel-card-#{shown.id}")
      refute has_element?(view, "#hotel-card-#{hidden.id}")
    end

    test "search patches the url and filters the grid", %{conn: conn} do
      matching = hotel_fixture(%{name: "Sarova Stanley Test"})
      other = hotel_fixture(%{name: "Beachcomber Test"})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/hotels")

      view
      |> element("#catalogue-search-form")
      |> render_submit(%{"q" => "Sarova"})

      assert_patch(view, "/tour-packages/hotels?q=Sarova")
      assert has_element?(view, "#hotel-card-#{matching.id}")
      refute has_element?(view, "#hotel-card-#{other.id}")
    end

    test "search with no matches shows the empty state", %{conn: conn} do
      hotel_fixture(%{name: "Only Hotel Test"})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/hotels")

      view
      |> element("#catalogue-search-form")
      |> render_submit(%{"q" => "zzzz-no-such-hotel"})

      assert has_element?(view, "#catalogue-empty")
    end

    test "opening a hotel renders the detail dialog with a booking CTA", %{conn: conn} do
      hotel = hotel_fixture(%{name: "Diani Sands Test", location: "Diani"})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/hotels")

      refute has_element?(view, "#catalogue-modal")

      view |> element("#hotel-card-#{hotel.id}") |> render_click()

      assert has_element?(view, "#catalogue-modal")
      assert has_element?(view, "#catalogue-modal-cta")
      assert view |> element("#catalogue-modal-cta") |> render() =~ "Diani"

      view |> element("#catalogue-modal-close") |> render_click()

      refute has_element?(view, "#catalogue-modal")
    end

    test "searching from the hub sends travellers to the hotel page", %{conn: conn} do
      hotel = hotel_fixture(%{name: "Hub Search Hotel Test"})

      {:ok, view, _html} = live(conn, ~p"/tour-packages")

      view
      |> element("#chyllz-hub-search-form")
      |> render_submit(%{"q" => "Hub Search"})

      assert_patch(view, "/tour-packages/hotels?q=Hub+Search")
      assert has_element?(view, "#hotel-card-#{hotel.id}")
    end
  end

  describe "hidden gems collection" do
    test "renders gems and searches them", %{conn: conn} do
      gem = hidden_gem_fixture(%{title: "Chale Island Test"})

      {:ok, view, _html} = live(conn, ~p"/our-packages/hidden-gems")

      assert has_element?(view, "#gem-card-#{gem.id}")

      view
      |> element("#catalogue-search-form")
      |> render_submit(%{"q" => "nothing-matches"})

      assert has_element?(view, "#catalogue-empty")
    end
  end

  describe "car hire collection" do
    test "renders vehicles from the database", %{conn: conn} do
      car = car_hire_fixture(%{car_name: "Prado Test", location: "Kisumu"})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/car")

      assert has_element?(view, "#car-card-#{car.id}")

      view |> element("#car-card-#{car.id}") |> render_click()
      assert has_element?(view, "#catalogue-modal")
    end
  end

  describe "events collection" do
    test "shows upcoming events and hides past ones", %{conn: conn} do
      upcoming = event_fixture(%{title: "Future Festival Test"})
      past = event_fixture(%{title: "Past Festival Test", date: Date.add(Date.utc_today(), -30)})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/events")

      assert has_element?(view, "#event-card-#{upcoming.id}")
      refute has_element?(view, "#event-card-#{past.id}")
    end

    test "falls back to recent events when nothing is upcoming", %{conn: conn} do
      past = event_fixture(%{title: "Recent Festival Test", date: Date.add(Date.utc_today(), -5)})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/events")

      assert has_element?(view, "#event-card-#{past.id}")
      assert render(view) =~ "Recently Held Events"
    end
  end
end
