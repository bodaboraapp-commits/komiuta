defmodule Xpressbus.ChyllzAccountTest do
  use Xpressbus.DataCase

  import Xpressbus.AccountsFixtures

  alias Xpressbus.ChyllzAccount
  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  defp ticket_fixture(user, attrs) do
    defaults = %{
      ticket_id: "TKT-#{System.unique_integer([:positive])}",
      from: "Nairobi",
      to: "Mombasa",
      travel_date: Date.utc_today(),
      departure: "7:00 AM",
      arrival: "1:30 PM",
      company: "MashPoa",
      price: "2300",
      seats: "[\"6\"]",
      passenger_name: user.name,
      passenger_phone: user.phone,
      payment_method: "mpesa",
      status: "confirmed",
      type: "One Way"
    }

    Repo.insert!(struct(Ticket, Map.merge(defaults, attrs)))
  end

  describe "stats/1" do
    test "counts trips, upcoming trips and distinct places visited" do
      user = user_fixture()
      today = Date.utc_today()

      ticket_fixture(user, %{to: "Kisumu", travel_date: Date.add(today, -10), status: "completed"})

      ticket_fixture(user, %{to: "Mombasa", travel_date: Date.add(today, -3), status: "completed"})

      ticket_fixture(user, %{to: "Mombasa", travel_date: Date.add(today, 5)})
      ticket_fixture(user, %{to: "Eldoret", travel_date: Date.add(today, 9), status: "cancelled"})

      assert %{trips: 4, upcoming: 1, places_visited: 2} = ChyllzAccount.stats(user)
    end

    test "is empty for a user without booking history" do
      user = user_fixture()

      assert %{trips: 0, upcoming: 0, places_visited: 0} = ChyllzAccount.stats(user)
    end

    test "does not count another passenger's tickets" do
      user = user_fixture()
      other = user_fixture()
      ticket_fixture(other, %{to: "Kisumu"})

      assert %{trips: 0, upcoming: 0} = ChyllzAccount.stats(user)
    end
  end

  describe "recent_trips/2" do
    test "returns the newest trips first, limited to the requested count" do
      user = user_fixture()
      today = Date.utc_today()

      ticket_fixture(user, %{to: "Kisumu", travel_date: Date.add(today, -20)})
      ticket_fixture(user, %{to: "Eldoret", travel_date: Date.add(today, -10)})
      ticket_fixture(user, %{to: "Nakuru", travel_date: Date.add(today, -5)})
      newest = ticket_fixture(user, %{to: "Mombasa", travel_date: Date.add(today, -1)})

      trips = ChyllzAccount.recent_trips(user, 3)

      assert length(trips) == 3
      assert hd(trips).id == newest.ticket_id
      assert hd(trips).title == "Nairobi → Mombasa"
      assert hd(trips).location == "Mombasa"
      assert hd(trips).status == "Completed"
      assert hd(trips).status_key == :completed
    end

    test "formats the card values for display" do
      user = user_fixture()
      future = Date.add(Date.utc_today(), 6)

      ticket_fixture(user, %{
        to: "KISUMU",
        travel_date: future,
        departure: "8:15 AM",
        arrival: "2:45 PM",
        price: "KSH 1500"
      })

      [trip] = ChyllzAccount.recent_trips(user, 1)

      assert trip.title == "Nairobi → Kisumu"
      assert trip.location == "Kisumu"
      assert trip.status == "Upcoming"
      assert trip.status_key == :upcoming
      assert trip.travel_date == Calendar.strftime(future, "%d %b, %Y")
      assert trip.departure == "8:15 AM – 2:45 PM"
      assert trip.fare == "Ksh 1,500"
    end

    test "returns an empty list for a user without tickets" do
      assert ChyllzAccount.recent_trips(user_fixture()) == []
    end
  end

  describe "overview/2" do
    test "assembles the page data with a default city" do
      user = user_fixture()
      ticket_fixture(user, %{to: "Kisumu", travel_date: Date.add(Date.utc_today(), 2)})

      overview = ChyllzAccount.overview(user)

      assert overview.stats.trips == 1
      assert overview.default_city == "Kisumu"
      assert length(overview.recent_trips) == 1
      assert overview.next_trip.id != nil
      assert length(overview.destinations) == 6
      assert overview.stories > 0
    end

    test "falls back to Nairobi when there is no trip history" do
      overview = ChyllzAccount.overview(user_fixture())

      assert overview.default_city == "Nairobi"
      assert overview.next_trip == nil
    end
  end

  describe "destinations/0" do
    test "returns unique linkable destinations" do
      destinations = ChyllzAccount.destinations()

      names = Enum.map(destinations, & &1.name)

      assert length(destinations) == 6
      assert length(Enum.uniq(names)) == 6
      assert "Mombasa" in names

      assert Enum.all?(
               destinations,
               &String.starts_with?(&1.search_url, "/tour-packages/hotels?q=")
             )

      assert Enum.all?(destinations, &is_binary(&1.slug))
    end
  end

  describe "format_money/1" do
    test "formats prices with the Ksh label and grouped digits" do
      assert ChyllzAccount.format_money("2300") == "Ksh 2,300"
      assert ChyllzAccount.format_money("KSH 1500") == "Ksh 1,500"
      assert ChyllzAccount.format_money("15000.00") == "Ksh 15,000"
      assert ChyllzAccount.format_money(nil) == "—"
      assert ChyllzAccount.format_money("Free") == "Free"
    end
  end
end
