defmodule Xpressbus.Bookings.CarHire do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "car_hires" do
    field(:car_name, :string)
    field(:type, :string)
    field(:price_per_day, :decimal)
    field(:location, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(car_hire, attrs) do
    car_hire
    |> cast(attrs, [:car_name, :type, :price_per_day, :location])
    |> validate_required([:car_name, :type, :price_per_day])
  end
end
