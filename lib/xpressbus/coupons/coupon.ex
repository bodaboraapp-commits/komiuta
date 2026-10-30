defmodule Xpressbus.Coupons.Coupon do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "coupons" do
    field(:code, :string)
    field(:type, :string)
    field(:value, :decimal)
    field(:min_amount, :decimal, default: 0)
    field(:max_discount, :decimal)
    field(:expiry_date, :date)
    field(:usage_limit, :integer)
    field(:usage_count, :integer, default: 0)
    field(:active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(coupon, attrs) do
    coupon
    |> cast(attrs, [
      :code,
      :type,
      :value,
      :min_amount,
      :max_discount,
      :expiry_date,
      :usage_limit,
      :usage_count,
      :active
    ])
    |> validate_required([:code, :type, :value, :active])
    |> update_change(:code, &normalise_code/1)
    |> validate_inclusion(:type, ["percentage", "fixed"])
    |> validate_number(:value, greater_than: 0)
    |> unique_constraint(:code)
  end

  defp normalise_code(code) do
    code |> to_string() |> String.trim() |> String.upcase()
  end
end
