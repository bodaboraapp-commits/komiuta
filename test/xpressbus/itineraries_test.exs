defmodule Xpressbus.ItinerariesTest do
  use Xpressbus.DataCase, async: true

  import Xpressbus.AccountsFixtures

  alias Xpressbus.Itineraries
  alias Xpressbus.Itineraries.SavedItinerary
  alias Xpressbus.TripItinerary

  @trip %{
    destination: "Cox's Bazar",
    country: "Bangladesh",
    start_date: ~D[2026-11-20],
    end_date: ~D[2026-11-22],
    travel_party: "couple",
    budget: "luxury",
    preferences: ["Beach Vacations", "Food Tourism"],
    latitude: 21.4272,
    longitude: 92.0058,
    place_source: :geocoding
  }

  defp itinerary(trip \\ @trip), do: TripItinerary.generate(trip)

  describe "save/3 and update/3" do
    test "persists the trip brief for the user" do
      user = user_fixture()

      assert {:ok, saved} = Itineraries.save(user, @trip, itinerary())

      assert saved.user_id == user.id
      assert saved.title == itinerary().title
      assert saved.title =~ "Cox's Bazar"
      assert saved.destination == "Cox's Bazar"
      assert saved.country == "Bangladesh"
      assert saved.start_date == ~D[2026-11-20]
      assert saved.end_date == ~D[2026-11-22]
      assert saved.budget == "luxury"
      assert saved.preferences == ~s(["Beach Vacations","Food Tourism"])
      assert saved.latitude == 21.4272
      assert saved.art in Itineraries.art_variants()
    end

    test "regenerates the same itinerary from the saved brief" do
      user = user_fixture()
      {:ok, saved} = Itineraries.save(user, @trip, itinerary())

      regenerated = Itineraries.itinerary(saved)

      assert regenerated.title == itinerary().title
      assert regenerated.map_embed_url =~ "output=embed"
      assert Itineraries.to_trip(saved).preferences == ["Beach Vacations", "Food Tourism"]
    end

    test "updates a saved itinerary in place" do
      user = user_fixture()
      {:ok, saved} = Itineraries.save(user, @trip, itinerary())

      updated_trip = %{@trip | budget: "balanced", preferences: ["Food Tourism"]}
      updated_itinerary = itinerary(updated_trip)

      assert {:ok, updated} = Itineraries.update(saved, updated_trip, updated_itinerary)
      assert updated.id == saved.id
      assert updated.budget == "balanced"
      assert updated.preferences == ~s(["Food Tourism"])
      assert length(Itineraries.list_for_user(user)) == 1
    end

    test "does not save without a user" do
      assert {:error, :not_signed_in} = Itineraries.save(nil, @trip, itinerary())
    end
  end

  describe "listing and ownership" do
    test "lists only the user's itineraries, newest first" do
      user = user_fixture()
      other_user = user_fixture()

      {:ok, first} = Itineraries.save(user, @trip, itinerary())

      {:ok, _other} =
        Itineraries.save(
          other_user,
          %{@trip | destination: "Rome"},
          itinerary(%{@trip | destination: "Rome"})
        )

      {:ok, second} =
        Itineraries.save(
          user,
          %{@trip | destination: "Diani"},
          itinerary(%{@trip | destination: "Diani"})
        )

      ids = Enum.map(Itineraries.list_for_user(user), & &1.id)
      other_ids = Enum.map(Itineraries.list_for_user(other_user), & &1.id)

      assert ids == [second.id, first.id]
      refute Enum.any?(other_ids, &(&1 in ids))
    end

    test "shows only the latest three saved itineraries" do
      user = user_fixture()

      saved =
        for index <- 1..4 do
          trip = %{@trip | destination: "Trip #{index}"}
          {:ok, saved_itinerary} = Itineraries.save(user, trip, itinerary(trip))
          saved_itinerary
        end

      listed = Itineraries.list_for_user(user)

      assert length(listed) == 3

      assert Enum.map(listed, & &1.id) ==
               saved |> Enum.reverse() |> Enum.take(3) |> Enum.map(& &1.id)
    end

    test "fetches one itinerary only for its owner" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, saved} = Itineraries.save(user, @trip, itinerary())

      assert %SavedItinerary{id: id} = Itineraries.get_for_user(user, saved.id)
      assert id == saved.id
      assert Itineraries.get_for_user(other_user, saved.id) == nil
      assert Itineraries.get_for_user(user, "not-an-id") == nil
    end
  end

  describe "trip status, duration and labels" do
    test "derives upcoming, ongoing and completed from the dates" do
      today = ~D[2026-11-10]
      upcoming = %SavedItinerary{start_date: ~D[2026-11-20], end_date: ~D[2026-11-22]}
      ongoing = %SavedItinerary{start_date: ~D[2026-11-08], end_date: ~D[2026-11-12]}
      completed = %SavedItinerary{start_date: ~D[2026-11-01], end_date: ~D[2026-11-05]}

      assert Itineraries.status(upcoming, today) == :upcoming
      assert Itineraries.status(ongoing, today) == :ongoing
      assert Itineraries.status(completed, today) == :completed
    end

    test "formats the status meta line" do
      today = ~D[2026-11-10]

      assert Itineraries.status_meta(
               %SavedItinerary{start_date: ~D[2026-11-20], end_date: ~D[2026-11-22]},
               today
             ) ==
               "10 Days Left"

      assert Itineraries.status_meta(
               %SavedItinerary{start_date: ~D[2026-11-08], end_date: ~D[2026-11-12]},
               today
             ) ==
               "Ends in 2 Days"

      assert Itineraries.status_meta(
               %SavedItinerary{start_date: ~D[2026-11-01], end_date: ~D[2026-11-05]},
               today
             ) ==
               "Nov 05, 2026"
    end

    test "formats duration, dates and budget labels" do
      saved = %SavedItinerary{
        start_date: ~D[2026-11-20],
        end_date: ~D[2026-11-22],
        budget: "luxury"
      }

      assert Itineraries.duration_days(saved) == 3
      assert Itineraries.duration_label(saved) == "3 Days"
      assert Itineraries.dates_label(saved) == "20 Nov, 2026"
      assert Itineraries.budget_label(saved) == "Luxury"
      assert Itineraries.budget_label(%SavedItinerary{budget: "cheap"}) == "Budget"
      assert Itineraries.budget_label(%SavedItinerary{budget: nil}) == "Flexible"
    end

    test "builds the card location, path and share link" do
      saved = %SavedItinerary{
        id: 42,
        destination: "Cox's Bazar",
        country: "Bangladesh",
        title: "Cox's Bazar Grandeur"
      }

      assert Itineraries.city_label(saved) == "Cox's Bazar, Bangladesh"
      assert Itineraries.path(saved) == "/trip/build-with-ai?saved=42"
      assert Itineraries.share_url(saved) =~ "https://wa.me/?text="
      assert Itineraries.share_url(saved) =~ "trip%2Fbuild-with-ai%3Fsaved%3D42"
    end

    test "handles invalid preference JSON safely" do
      assert Itineraries.preferences(%SavedItinerary{preferences: "not json"}) == []
      assert Itineraries.preferences(%SavedItinerary{preferences: nil}) == []
    end
  end
end
