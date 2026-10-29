defmodule Xpressbus.Insurance.InsurancePlan do
  @moduledoc """
  A travel insurance product shown on the InSURE page.

  Plans are ordered by `position`, may be marked `popular` (highlighted in the
  pricing grid) and can be disabled with `active: false` without losing the
  historical row.

  `features` is an ordered list of benefit bullet points. `coverage` is an
  ordered list of maps with `"label"` and `"value"` keys, which lets the
  coverage comparison table be rendered straight from the database without a
  hard-coded benefit list.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @feature_max 20
  @coverage_max 20

  schema "insurance_plans" do
    field(:name, :string)
    field(:price, :decimal)
    field(:period, :string)
    field(:tagline, :string)
    field(:features, {:array, :string}, default: [])
    field(:coverage, {:array, :map}, default: [])
    field(:popular, :boolean, default: false)
    field(:active, :boolean, default: true)
    field(:position, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [
      :name,
      :price,
      :period,
      :tagline,
      :features,
      :coverage,
      :popular,
      :active,
      :position
    ])
    |> validate_required([:name, :price, :period])
    |> validate_length(:name, max: 120)
    |> validate_length(:period, max: 40)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_length(:features, max: @feature_max)
    |> validate_length(:coverage, max: @coverage_max)
    |> unique_constraint(:name)
  end
end
