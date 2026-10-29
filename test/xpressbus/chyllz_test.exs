defmodule Xpressbus.ChyllzTest do
  use Xpressbus.DataCase

  import Xpressbus.CatalogueFixtures

  alias Xpressbus.Chyllz

  describe "hotels/1" do
    test "only returns active hotels" do
      live = hotel_fixture(%{name: "Active Hotel Test"})
      hidden = hotel_fixture(%{name: "Hidden Hotel Test", active: false})

      hotels = Chyllz.hotels()
      ids = Enum.map(hotels, & &1.id)

      assert live.id in ids
      refute hidden.id in ids
    end

    test "searches name, location and description case-insensitively" do
      by_name = hotel_fixture(%{name: "Zanzibar Beach House Test"})
      by_location = hotel_fixture(%{name: "Other Stay", location: "Zanzibar Town"})
      by_description = hotel_fixture(%{name: "Third Stay", description: "Overlooks Zanzibar bay"})

      unrelated =
        hotel_fixture(%{name: "Kisumu Lodge", location: "Kisumu", description: "Lakeside"})

      ids =
        Chyllz.hotels(search: "zAnZiBaR")
        |> Enum.map(& &1.id)

      assert by_name.id in ids
      assert by_location.id in ids
      assert by_description.id in ids
      refute unrelated.id in ids
    end

    test "respects the requested limit" do
      for _ <- 1..3, do: hotel_fixture()

      assert length(Chyllz.hotels(limit: 1)) == 1
    end
  end

  describe "hidden_gems/1" do
    test "only returns active gems and applies search" do
      active = hidden_gem_fixture(%{title: "Maasai Mara Sunrise Test"})
      inactive = hidden_gem_fixture(%{title: "Hidden Gem Test", active: false})

      gems = Chyllz.hidden_gems(search: "maasai")
      ids = Enum.map(gems, & &1.id)

      assert active.id in ids
      refute inactive.id in ids
    end
  end

  describe "car_hires/1" do
    test "keeps the same vehicle as a separate offer in a different town" do
      first = car_hire_fixture(%{car_name: "Landcruiser V8 Test", location: "Nairobi"})
      second = car_hire_fixture(%{car_name: "Landcruiser V8 Test", location: "Mombasa"})

      cars = Chyllz.car_hires(search: "landcruiser")
      ids = Enum.map(cars, & &1.id)

      assert first.id in ids
      assert second.id in ids
    end
  end

  describe "events" do
    test "upcoming_events/1 returns future events earliest first" do
      soon = event_fixture(%{date: Date.add(Date.utc_today(), 3)})
      later = event_fixture(%{date: Date.add(Date.utc_today(), 30)})
      past = event_fixture(%{date: Date.add(Date.utc_today(), -10)})
      inactive = event_fixture(%{date: Date.add(Date.utc_today(), 5), active: false})

      events = Chyllz.upcoming_events()
      ids = Enum.map(events, & &1.id)

      assert soon.id in ids
      assert later.id in ids
      refute past.id in ids
      refute inactive.id in ids
      assert Enum.find_index(ids, &(&1 == soon.id)) < Enum.find_index(ids, &(&1 == later.id))
    end

    test "past_events/1 returns only events that already happened, newest first" do
      recent = event_fixture(%{date: Date.add(Date.utc_today(), -2)})
      older = event_fixture(%{date: Date.add(Date.utc_today(), -40)})
      upcoming = event_fixture(%{date: Date.add(Date.utc_today(), 7)})

      events = Chyllz.past_events()
      ids = Enum.map(events, & &1.id)

      assert recent.id in ids
      assert older.id in ids
      refute upcoming.id in ids
      assert Enum.find_index(ids, &(&1 == recent.id)) < Enum.find_index(ids, &(&1 == older.id))
    end
  end

  describe "counts/0" do
    test "counts distinct active catalogue entries" do
      before = Chyllz.counts()

      hotel_fixture()
      hidden_gem_fixture()
      car_hire_fixture()
      event_fixture()
      hotel_fixture(%{active: false})

      after_counts = Chyllz.counts()

      assert after_counts.hotels == before.hotels + 1
      assert after_counts.hidden_gems == before.hidden_gems + 1
      assert after_counts.car_hires == before.car_hires + 1
      assert after_counts.events == before.events + 1
    end
  end
end
