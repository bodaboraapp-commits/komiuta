defmodule Xpressbus.AgentsTest do
  use Xpressbus.DataCase

  alias Xpressbus.Agents

  defp attrs do
    %{
      "full_name" => "Agent Tester",
      "business_name" => "Tester Travel",
      "email" => "agent.tester@example.com",
      "phone" => "0723456789",
      "city" => "Nairobi",
      "routes" => "Nairobi - Kisumu",
      "payout_method" => "mpesa"
    }
  end

  test "creates a pending agent application with a reference" do
    assert {:ok, application} = Agents.create_application(attrs())
    assert application.status == "pending"
    assert application.reference =~ "AGT-"
    assert application.email == "agent.tester@example.com"
  end

  test "rejects incomplete applications" do
    assert {:error, changeset} = Agents.create_application(%{"full_name" => "X"})
    assert changeset.errors[:email]
    assert changeset.errors[:business_name]
  end

  test "admin can approve and reject an application" do
    {:ok, application} = Agents.create_application(attrs())

    assert {:ok, approved} = Agents.update_status(application, "approved")
    assert approved.status == "approved"
    assert approved.reviewed_at

    assert {:ok, rejected} = Agents.update_status(approved, "rejected")
    assert rejected.status == "rejected"
  end

  test "lists and counts pending applications" do
    {:ok, _} = Agents.create_application(attrs())

    assert Agents.count_pending() == 1
    assert length(Agents.list_applications()) == 1
    assert {[_], 1} = Agents.paginate_applications(1, 20, "Tester")
  end
end
