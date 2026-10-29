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
    field(:active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(car_hire, attrs) do
    car_hire
    |> cast(attrs, [:car_name, :type, :price_per_day, :location, :active])
    |> validate_required([:car_name, :type, :price_per_day])
    |> unique_constraint(:car_name, name: :car_hires_car_name_location_index)
  end
end
