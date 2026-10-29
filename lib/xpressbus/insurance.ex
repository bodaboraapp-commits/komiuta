defmodule Xpressbus.Insurance do
  @moduledoc """
  The Insurance context powers the public InSURE page.

  Historically the InSURE page rendered a hard-coded list of plans, inclusions
  and FAQs. Everything on that page now comes from the `insurance_plans` and
  `insurance_faqs` tables, so the cover on offer can be changed without a
  deploy.

  Public readers only see `active` rows, ordered by their configured
  `position`, which means marketing can stage a plan or FAQ by saving it
  inactive. Admin readers (`list_plans/0`, `list_faqs/0`) see everything.
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Insurance.{InsuranceFaq, InsurancePlan, SeedData}

  @doc "Lists the plans that are live on the public InSURE page, in display order."
  def list_active_plans do
    Repo.all(
      from(p in InsurancePlan,
        where: p.active == true,
        order_by: [asc: p.position, asc: p.name]
      )
    )
  end

  @doc "Lists every plan, including inactive ones, for the admin catalogue."
  def list_plans do
    Repo.all(from(p in InsurancePlan, order_by: [asc: p.position, asc: p.name]))
  end

  @doc "Counts every insurance plan, including inactive ones."
  def count_plans, do: Repo.aggregate(InsurancePlan, :count, :id)

  @doc "Lists the FAQs that are live on the public InSURE page, in display order."
  def list_active_faqs do
    Repo.all(
      from(f in InsuranceFaq,
        where: f.active == true,
        order_by: [asc: f.position, asc: f.id]
      )
    )
  end

  @doc "Lists every FAQ, including inactive ones, for the admin catalogue."
  def list_faqs do
    Repo.all(from(f in InsuranceFaq, order_by: [asc: f.position, asc: f.id]))
  end

  @doc "Counts every insurance FAQ, including inactive ones."
  def count_faqs, do: Repo.aggregate(InsuranceFaq, :count, :id)

  @doc "Creates a plan from the given attributes."
  def create_plan(attrs) do
    %InsurancePlan{}
    |> InsurancePlan.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Creates a FAQ from the given attributes."
  def create_faq(attrs) do
    %InsuranceFaq{}
    |> InsuranceFaq.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Inserts the default launch plans and FAQs when they are missing.

  Idempotent: existing plans are matched by name and existing FAQs by
  question, so re-running it never duplicates content. Called by the
  `create_insurance_tables` migration and by `priv/repo/seeds.exs`.
  """
  def ensure_defaults do
    Enum.each(SeedData.plans(), fn attrs ->
      unless Repo.get_by(InsurancePlan, name: attrs.name) do
        %InsurancePlan{}
        |> InsurancePlan.changeset(attrs)
        |> Repo.insert!()
      end
    end)

    Enum.each(SeedData.faqs(), fn attrs ->
      unless Repo.get_by(InsuranceFaq, question: attrs.question) do
        %InsuranceFaq{}
        |> InsuranceFaq.changeset(attrs)
        |> Repo.insert!()
      end
    end)

    :ok
  end

  @doc """
  Builds the rows of the coverage comparison table.

  Returns a list of `{label, values}` tuples where `values` has one entry per
  plan (in the same order as the plans given). The label order is the order in
  which labels first appear across the plans, so it follows the catalogue
  rather than a hard-coded table.
  """
  def coverage_rows(plans) when is_list(plans) do
    labels =
      plans
      |> Enum.flat_map(fn plan -> plan |> coverage_entries() |> Enum.map(&label/1) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    Enum.map(labels, fn label ->
      values = Enum.map(plans, &coverage_value(&1, label))
      {label, values}
    end)
  end

  @doc "Returns the cheapest active plan price, or `nil` when there are no plans."
  def starting_price(plans) when is_list(plans) do
    plans
    |> Enum.map(& &1.price)
    |> Enum.reject(&is_nil/1)
    |> Enum.min(fn -> nil end)
  end

  defp coverage_entries(%InsurancePlan{coverage: coverage}) when is_list(coverage), do: coverage
  defp coverage_entries(_plan), do: []

  defp label(%{"label" => label}) when is_binary(label) and label != "", do: label
  defp label(%{label: label}) when is_binary(label) and label != "", do: label
  defp label(_entry), do: nil

  defp coverage_value(plan, label) do
    plan
    |> coverage_entries()
    |> Enum.find(fn entry -> label(entry) == label end)
    |> case do
      nil -> "—"
      %{"value" => value} when is_binary(value) and value != "" -> value
      %{value: value} when is_binary(value) and value != "" -> value
      _other -> "—"
    end
  end
end
