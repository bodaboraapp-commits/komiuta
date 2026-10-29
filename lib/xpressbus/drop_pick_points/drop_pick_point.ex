defmodule Xpressbus.DropPickPoints.DropPickPoint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "drop_pick_points" do
    field(:name, :string)
    field(:location, :string)
    field(:city, :string)
    field(:active, :boolean, default: true)

    belongs_to(:city_record, Xpressbus.Cities.City, foreign_key: :city_id)

    timestamps(type: :utc_datetime)
  end

  def changeset(drop_pick_point, attrs) do
    drop_pick_point
    |> cast(attrs, [:name, :location, :city, :active, :city_id])
    |> validate_required([:name])
    |> unique_constraint(:name)
    |> foreign_key_constraint(:city_id)
  end
end
