defmodule Xpressbus.TripItineraryTest do
  use ExUnit.Case, async: true

  alias Xpressbus.TripItinerary

  defp trip(overrides \\ %{}) do
    Map.merge(
      %{
        destination: "Moscow",
        country: "Russia",
        latitude: 55.7558,
        longitude: 37.6173,
        start_date: ~D[2026-12-10],
        end_date: ~D[2026-12-14],
        travel_party: "couple",
        budget: "luxury",
        preferences: ["Cultural Exploration"],
        pets: false
      },
      overrides
    )
  end

  test "builds the itinerary title from the traveller's preferences" do
    itinerary = TripItinerary.generate(trip(), live_places: false)

    assert itinerary.title == "Moscow: A Cultural Luxury Escape"
    refute itinerary.title =~ "Grandeur"
    refute itinerary.overview =~ ~r/grandeur/i
  end

  test "changes the title when the brief changes" do
    beach =
      TripItinerary.generate(trip(%{preferences: ["Beach Vacations"], budget: "balanced"}),
        live_places: false
      )

    food =
      TripItinerary.generate(trip(%{preferences: ["Food Tourism"], budget: "cheap"}),
        live_places: false
      )

    assert beach.title == "Moscow: A Beach Balanced Escape"
    assert food.title == "Moscow: A Food & Culture Budget Escape"
    assert beach.title != food.title
  end

  test "uses the travel party when no preferences were selected" do
    family =
      TripItinerary.generate(trip(%{preferences: [], travel_party: "family"}), live_places: false)

    friends =
      TripItinerary.generate(trip(%{preferences: [], travel_party: "friends"}),
        live_places: false
      )

    assert family.title == "Moscow: A Family Luxury Escape"
    assert friends.title == "Moscow: A Group Luxury Escape"
  end
end
