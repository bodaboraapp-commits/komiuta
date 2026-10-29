defmodule Xpressbus.Routes.Route do
  use Ecto.Schema
  import Ecto.Changeset

  schema "routes" do
    field(:origin, :string)
    field(:destination, :string)
    field(:distance, :string)
    field(:duration, :string)
    field(:active, :boolean, default: true)

    field(:origin_city_id, :id)
    field(:destination_city_id, :id)

    belongs_to(:origin_city, Xpressbus.Cities.City,
      foreign_key: :origin_city_id,
      define_field: false
    )

    belongs_to(:destination_city, Xpressbus.Cities.City,
      foreign_key: :destination_city_id,
      define_field: false
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(route, attrs) do
    route
    |> cast(attrs, [
      :origin,
      :destination,
      :distance,
      :duration,
      :active,
      :origin_city_id,
      :destination_city_id
    ])
    |> validate_required([:origin, :destination])
    |> unique_constraint([:origin, :destination])
    |> foreign_key_constraint(:origin_city_id)
    |> foreign_key_constraint(:destination_city_id)
  end
end
