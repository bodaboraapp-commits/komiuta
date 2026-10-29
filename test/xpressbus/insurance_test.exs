defmodule Xpressbus.InsuranceTest do
  use Xpressbus.DataCase

  import Xpressbus.CatalogueFixtures

  alias Xpressbus.Insurance
  alias Xpressbus.Insurance.InsurancePlan

  describe "plans" do
    test "list_active_plans/0 hides inactive plans and keeps position order" do
      later = insurance_plan_fixture(%{position: 900_002})
      earlier = insurance_plan_fixture(%{position: 900_001})
      hidden = insurance_plan_fixture(%{position: 900_000, active: false})

      plans = Insurance.list_active_plans()
      ids = Enum.map(plans, & &1.id)

      assert earlier.id in ids
      assert later.id in ids
      refute hidden.id in ids
      assert Enum.find_index(ids, &(&1 == earlier.id)) < Enum.find_index(ids, &(&1 == later.id))
    end

    test "list_plans/0 includes inactive plans for the admin catalogue" do
      hidden = insurance_plan_fixture(%{active: false})

      assert hidden.id in Enum.map(Insurance.list_plans(), & &1.id)
    end

    test "create_plan/1 validates required fields" do
      assert {:error, changeset} = Insurance.create_plan(%{name: nil, price: nil, period: nil})
      assert %{name: [_], price: [_], period: [_]} = errors_on(changeset)
    end

    test "starting_price/1 returns the cheapest plan price" do
      insurance_plan_fixture(%{price: "100"})
      insurance_plan_fixture(%{price: "5000"})

      assert Decimal.equal?(Insurance.starting_price(Insurance.list_active_plans()), "100")
    end

    test "starting_price/1 returns nil with no plans" do
      Repo.delete_all(InsurancePlan)

      assert Insurance.starting_price([]) == nil
    end
  end

  describe "faqs" do
    test "list_active_faqs/0 hides inactive FAQs" do
      visible = insurance_faq_fixture(%{position: 900_001})
      hidden = insurance_faq_fixture(%{position: 900_002, active: false})

      ids = Enum.map(Insurance.list_active_faqs(), & &1.id)

      assert visible.id in ids
      refute hidden.id in ids
    end
  end

  describe "ensure_defaults/0" do
    test "is idempotent and seeds the default catalogue" do
      before = {Insurance.count_plans(), Insurance.count_faqs()}

      assert :ok = Insurance.ensure_defaults()
      assert :ok = Insurance.ensure_defaults()

      assert {Insurance.count_plans(), Insurance.count_faqs()} == before
      assert Insurance.count_plans() > 0
      assert Insurance.count_faqs() > 0
    end
  end

  describe "coverage_rows/1" do
    test "builds comparison rows from plan coverage data in first-seen label order" do
      first =
        insurance_plan_fixture(%{
          coverage: [
            %{"label" => "Trip Cancellation", "value" => "Ksh 100,000"},
            %{"label" => "Medical Expenses", "value" => "Ksh 500,000"}
          ]
        })

      second =
        insurance_plan_fixture(%{
          coverage: [
            %{"label" => "Medical Expenses", "value" => "Ksh 2,000,000"},
            %{"label" => "Gadget Protection", "value" => "Included"}
          ]
        })

      rows = Insurance.coverage_rows([first, second])

      assert [
               {"Trip Cancellation", ["Ksh 100,000", "—"]},
               {"Medical Expenses", ["Ksh 500,000", "Ksh 2,000,000"]},
               {"Gadget Protection", ["—", "Included"]}
             ] = rows
    end

    test "ignores plans without coverage data" do
      plan = insurance_plan_fixture(%{coverage: []})

      assert Insurance.coverage_rows([plan]) == []
    end
  end
end
