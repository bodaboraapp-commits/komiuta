defmodule Xpressbus.TripFinancesTest do
  use Xpressbus.DataCase, async: true

  import Xpressbus.AccountsFixtures

  alias Xpressbus.{Repo, TripFinances}

  defp saved_itinerary_fixture(user) do
    today = Date.utc_today()

    trip = %{
      destination: "Cox's Bazar",
      country: "Bangladesh",
      start_date: Date.add(today, 2),
      end_date: Date.add(today, 5),
      travel_party: "couple",
      budget: "luxury",
      preferences: ["Beach Vacations"],
      latitude: 21.4272,
      longitude: 92.0058
    }

    {:ok, saved} = Xpressbus.Itineraries.save(user, trip, Xpressbus.TripItinerary.generate(trip))
    saved
  end

  describe "budget" do
    test "persists and updates a budget for a bus trip" do
      user = user_fixture()
      scope = TripFinances.scope(user, :ticket, "TKT-1")

      assert TripFinances.get_budget(scope) == 0.0
      assert {:ok, 25_000.0} = TripFinances.set_budget(scope, 25_000)
      assert TripFinances.get_budget(scope) == 25_000.0

      assert {:ok, 30_000.0} = TripFinances.set_budget(scope, 30_000)
      assert TripFinances.get_budget(scope) == 30_000.0
      assert Repo.aggregate(TripFinances.TripBudget, :count, :id) == 1
    end

    test "keeps a saved itinerary budget separate from any ticket budget" do
      user = user_fixture()
      saved = saved_itinerary_fixture(user)

      ticket_scope = TripFinances.scope(user, :ticket, "TKT-1")
      itinerary_scope = TripFinances.scope(user, :saved, saved.id)

      assert {:ok, _} = TripFinances.set_budget(ticket_scope, 5_000)
      assert {:ok, _} = TripFinances.set_budget(itinerary_scope, 40_000)

      assert TripFinances.get_budget(ticket_scope) == 5_000.0
      assert TripFinances.get_budget(itinerary_scope) == 40_000.0
    end

    test "scopes budgets to the owning user" do
      owner = user_fixture()
      other = user_fixture()

      assert {:ok, _} =
               TripFinances.set_budget(TripFinances.scope(owner, :ticket, "TKT-1"), 5_000)

      assert TripFinances.get_budget(TripFinances.scope(other, :ticket, "TKT-1")) == 0.0
    end
  end

  describe "expenses" do
    test "adds, lists and deletes expenses for a trip" do
      user = user_fixture()
      scope = TripFinances.scope(user, :ticket, "TKT-1")

      assert {:ok, food} =
               TripFinances.add_expense(scope, %{
                 label: "Lunch",
                 category: "Food",
                 amount: 850,
                 spent_on: ~D[2026-11-10]
               })

      assert {:ok, transport} =
               TripFinances.add_expense(scope, %{
                 label: "Taxi",
                 category: "Transport",
                 amount: 1_200,
                 spent_on: ~D[2026-11-11]
               })

      rows = TripFinances.list_expenses(scope)

      assert Enum.map(rows, & &1.label) == ["Taxi", "Lunch"]
      assert Enum.map(rows, & &1.amount) == [1_200.0, 850.0]
      assert Enum.map(rows, & &1.category) == ["Transport", "Food"]

      assert :ok = TripFinances.delete_expense(scope, food.id)
      assert Enum.map(TripFinances.list_expenses(scope), & &1.id) == [transport.id]
    end

    test "keeps saved itinerary expenses separate and user-scoped" do
      user = user_fixture()
      other = user_fixture()
      saved = saved_itinerary_fixture(user)

      itinerary_scope = TripFinances.scope(user, :saved, saved.id)
      ticket_scope = TripFinances.scope(user, :ticket, "TKT-1")
      other_scope = TripFinances.scope(other, :saved, saved.id)

      assert {:ok, _} =
               TripFinances.add_expense(itinerary_scope, %{
                 label: "Resort",
                 category: "Stay",
                 amount: 12_000,
                 spent_on: Date.utc_today()
               })

      assert length(TripFinances.list_expenses(itinerary_scope)) == 1
      assert TripFinances.list_expenses(ticket_scope) == []
      assert TripFinances.list_expenses(other_scope) == []
    end

    test "rejects expenses without an amount or label" do
      user = user_fixture()
      scope = TripFinances.scope(user, :ticket, "TKT-1")

      assert {:error, changeset} =
               TripFinances.add_expense(scope, %{
                 label: "",
                 category: "Food",
                 amount: 100,
                 spent_on: Date.utc_today()
               })

      assert changeset.errors[:label]
    end
  end
end
