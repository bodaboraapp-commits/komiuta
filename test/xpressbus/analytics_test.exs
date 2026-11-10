defmodule Xpressbus.AnalyticsTest do
  use Xpressbus.DataCase

  alias Xpressbus.Analytics

  test "records events and builds the three production funnels" do
    assert {:ok, _} = Analytics.track("signup_started")
    assert {:ok, _} = Analytics.track("signup_details_viewed")
    assert {:ok, _} = Analytics.track("signup_completed")
    assert {:ok, _} = Analytics.track("ai_itinerary_generated")
    assert {:ok, _} = Analytics.track("ai_itinerary_saved")
    assert {:ok, _} = Analytics.track("ai_itinerary_refined")
    assert {:ok, _} = Analytics.track("manage_itinerary_opened")
    assert {:ok, _} = Analytics.track("manage_itinerary_budget_set")
    assert {:ok, _} = Analytics.track("manage_itinerary_expense_added")

    funnels = Analytics.funnel_report(30)
    assert Enum.map(funnels, & &1.key) == ["signup", "ai", "manage"]

    signup = Enum.find(funnels, &(&1.key == "signup"))
    assert signup.total == 1
    assert Enum.map(signup.stages, & &1.count) == [1, 0, 1, 1]

    ai = Enum.find(funnels, &(&1.key == "ai"))
    assert ai.total == 1
    assert Enum.map(ai.stages, & &1.count) == [1, 1, 1]

    manage = Enum.find(funnels, &(&1.key == "manage"))
    assert manage.total == 1
    assert Enum.map(manage.stages, & &1.count) == [1, 1, 1]
  end

  test "ignores events older than the selected reporting period" do
    old = DateTime.add(DateTime.utc_now(), -40, :day) |> DateTime.truncate(:second)

    assert {:ok, event} = Analytics.track("signup_started")
    event |> Ecto.Changeset.change(inserted_at: old) |> Xpressbus.Repo.update!()

    assert Enum.find(Analytics.funnel_report(30), &(&1.key == "signup")).total == 0
    assert Enum.find(Analytics.funnel_report(90), &(&1.key == "signup")).total == 1
  end
end
