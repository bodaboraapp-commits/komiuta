defmodule XpressbusWeb.InsuranceLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.CatalogueFixtures

  alias Xpressbus.Insurance.InsurancePlan
  alias Xpressbus.Repo

  describe "insurance page" do
    test "renders plans, coverage table and FAQs from the database", %{conn: conn} do
      plan = insurance_plan_fixture(%{name: "Test Cover Plan", price: "2500"})
      faq = insurance_faq_fixture(%{question: "Is this DB backed?"})

      {:ok, view, html} = live(conn, ~p"/tour-packages/insurance")

      assert html =~ "Travel with Confidence"
      assert has_element?(view, "#plan-card-#{plan.id}")
      assert has_element?(view, "#coverage-table")
      assert has_element?(view, "#insurance-faq-#{faq.id}")
      assert has_element?(view, "#insurance-starting-price")
    end

    test "hides inactive plans and FAQs", %{conn: conn} do
      plan = insurance_plan_fixture(%{name: "Hidden Cover Plan", active: false})
      faq = insurance_faq_fixture(%{question: "Hidden question?", active: false})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/insurance")

      refute has_element?(view, "#plan-card-#{plan.id}")
      refute has_element?(view, "#insurance-faq-#{faq.id}")
    end

    test "selecting a plan shows activation guidance", %{conn: conn} do
      plan = insurance_plan_fixture(%{name: "Selectable Cover Plan"})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/insurance")

      refute has_element?(view, "#insurance-selection")

      view |> element("#plan-card-#{plan.id} button") |> render_click()

      assert has_element?(view, "#insurance-selection")
      assert has_element?(view, "#insurance-selection a[href='tel:0800211211']")

      view |> element("#insurance-selection button") |> render_click()

      refute has_element?(view, "#insurance-selection")
    end

    test "shows the cheapest active plan in the closing pitch", %{conn: conn} do
      insurance_plan_fixture(%{name: "Cheapest Cover Plan", price: "100"})

      {:ok, view, _html} = live(conn, ~p"/tour-packages/insurance")

      assert view |> element("#insurance-starting-price") |> render() =~ "Ksh 100 per trip"
    end

    test "renders an empty state when no plans are available", %{conn: conn} do
      Repo.delete_all(InsurancePlan)

      {:ok, view, _html} = live(conn, ~p"/tour-packages/insurance")

      assert has_element?(view, "#insurance-empty")
      refute has_element?(view, "#coverage-table")
    end
  end
end
