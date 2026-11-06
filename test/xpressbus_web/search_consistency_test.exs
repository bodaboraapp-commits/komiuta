defmodule XpressbusWeb.SearchConsistencyTest do
  @moduledoc """
  Public bus visibility must be identical on every search/browse surface:

    * booking search results (`/buses/...`)
    * the BuuPass cache fallback (`Scraper.search/3`)
    * city landing pages (`/cities/...`)
    * operator pages (`/operators`)
    * SEO route discovery (`/sitemap.xml`)

  All of them must ignore `legacy_fallback` rows, sold-out buses and buses
  belonging to unapproved partner operators, and the dated search must also
  apply the 2-hour departure window.
  """

  use XpressbusWeb.ConnCase, async: false

  alias Xpressbus.Bookings.{Bus, Scraper, Search}
  alias Xpressbus.BusOperators.BusOperator
  alias Xpressbus.Repo

  @travel_date ~D[2026-11-20]

  defp operator_fixture(name, active) do
    Repo.insert!(%BusOperator{name: name, active: active})
  end

  defp bus_fixture(attrs) do
    defaults = %{
      company: "Consistency Coach",
      departure: "10:00 AM",
      arrival: "2:00 PM",
      seats: "20 seats left",
      price: "KSH 1,500",
      registration: "CON #{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Mombasa",
      travel_date: @travel_date,
      duration: "8h 0m",
      occupied_seats: [],
      total_seats: 40
    }

    %Bus{}
    |> Bus.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  setup do
    approved = operator_fixture("Consistent Approved #{System.unique_integer([:positive])}", true)
    unapproved = operator_fixture("Consistent Unapproved", false)

    approved_bus =
      bus_fixture(%{
        company: "Consistent Approved",
        bus_operator_id: approved.id
      })

    unapproved_bus =
      bus_fixture(%{
        company: "Consistent Unapproved",
        bus_operator_id: unapproved.id
      })

    legacy_bus = bus_fixture(%{company: "Consistent Legacy", source: "legacy_fallback"})
    sold_out_bus = bus_fixture(%{company: "Consistent SoldOut", seats: "0 seats left"})

    ghost_bus =
      bus_fixture(%{
        company: "Consistent Unapproved",
        bus_operator_id: unapproved.id,
        from: "Ghostville",
        to: "Nowhere"
      })

    %{
      approved_bus: approved_bus,
      unapproved_bus: unapproved_bus,
      legacy_bus: legacy_bus,
      sold_out_bus: sold_out_bus,
      ghost_bus: ghost_bus
    }
  end

  test "Search.list_bookable and Scraper.search return the same approved buses", %{
    approved_bus: approved_bus,
    unapproved_bus: unapproved_bus,
    legacy_bus: legacy_bus,
    sold_out_bus: sold_out_bus
  } do
    search_ids = Search.list_bookable("Nairobi", "Mombasa", @travel_date) |> Enum.map(& &1.id)
    scraper_ids = Scraper.search("Nairobi", "Mombasa", @travel_date) |> Enum.map(& &1.id)

    assert search_ids == scraper_ids
    assert approved_bus.id in search_ids

    refute unapproved_bus.id in search_ids
    refute legacy_bus.id in search_ids
    refute sold_out_bus.id in search_ids
  end

  test "booking search results use the same visibility rules", %{approved_bus: approved_bus} do
    html =
      build_conn()
      |> get(
        "/buses/Nairobi-to-Mombasa?fromCityName=Nairobi&toCityName=Mombasa&onward=#{@travel_date}"
      )
      |> html_response(200)

    assert html =~ approved_bus.company
    refute html =~ "Consistent Unapproved"
    refute html =~ "Consistent Legacy"
    refute html =~ "Consistent SoldOut"
  end

  test "city landing pages only aggregate approved, bookable buses", %{approved_bus: approved_bus} do
    html = build_conn() |> get("/cities/nairobi") |> html_response(200)

    assert html =~ "Mombasa"
    assert html =~ approved_bus.company

    refute html =~ "Consistent Unapproved"
    refute html =~ "Consistent Legacy"
    refute html =~ "Consistent SoldOut"
  end

  test "operator pages only list approved operators", %{approved_bus: approved_bus} do
    html = build_conn() |> get("/operators") |> html_response(200)

    assert html =~ approved_bus.company
    refute html =~ "Consistent Unapproved"
    refute html =~ "Consistent Legacy"
    refute html =~ "Consistent SoldOut"
  end

  test "sitemap route discovery ignores unapproved-only routes", %{ghost_bus: ghost_bus} do
    assert ghost_bus.from == "Ghostville"

    html = build_conn() |> get("/sitemap.xml") |> response(200)

    assert html =~ "/buses/Nairobi-to-Mombasa"
    refute html =~ "Ghostville"
  end
end
