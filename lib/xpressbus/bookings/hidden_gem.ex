defmodule Xpressbus.Bookings.HiddenGem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "hidden_gems" do
    field(:title, :string)
    field(:location, :string)
    field(:description, :string)
    field(:images, {:array, :string}, default: [])
    field(:active, :boolean, default: true)

    field(:category, :string)
    field(:region, :string)
    field(:best_time, :string)
    field(:entry_fee, :string)
    field(:access_notes, :string)
    field(:website_url, :string)
    field(:source_url, :string)
    field(:source_checked_at, :utc_datetime)
    field(:latitude, :float)
    field(:longitude, :float)
    field(:google_place_id, :string)
    field(:google_maps_url, :string)
    field(:google_photo_ref, :string)
    field(:formatted_address, :string)
    field(:rating, :decimal)
    field(:review_count, :integer)
    field(:google_synced_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(hidden_gem, attrs) do
    hidden_gem
    |> cast(attrs, [
      :title,
      :location,
      :description,
      :images,
      :active,
      :category,
      :region,
      :best_time,
      :entry_fee,
      :access_notes,
      :website_url,
      :source_url,
      :source_checked_at,
      :latitude,
      :longitude,
      :google_place_id,
      :google_maps_url,
      :google_photo_ref,
      :formatted_address,
      :rating,
      :review_count,
      :google_synced_at
    ])
    |> validate_required([:title, :location])
    |> unique_constraint(:title)
  end
end
