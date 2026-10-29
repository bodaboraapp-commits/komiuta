defmodule Xpressbus.Bookings.Hotel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "hotels" do
    field(:name, :string)
    field(:price_per_night, :decimal)
    field(:rating, :decimal)
    field(:location, :string)
    field(:description, :string)
    field(:amenities, {:array, :string}, default: [])
    field(:images, {:array, :string}, default: [])

    timestamps(type: :utc_datetime)
  end

  def changeset(hotel, attrs) do
    hotel
    |> cast(attrs, [
      :name,
      :price_per_night,
      :rating,
      :location,
      :description,
      :amenities,
      :images
    ])
    |> validate_required([:name, :price_per_night, :location])
  end
end
