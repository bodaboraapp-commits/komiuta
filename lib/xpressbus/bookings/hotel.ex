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
    field(:active, :boolean, default: true)

    field(:google_place_id, :string)
    field(:google_maps_url, :string)
    field(:google_photo_ref, :string)
    field(:formatted_address, :string)
    field(:review_count, :integer)
    field(:google_synced_at, :utc_datetime)

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
      :images,
      :active,
      :google_place_id,
      :google_maps_url,
      :google_photo_ref,
      :formatted_address,
      :review_count,
      :google_synced_at
    ])
    |> validate_required([:name, :price_per_night, :location])
    |> unique_constraint(:name)
  end
end
