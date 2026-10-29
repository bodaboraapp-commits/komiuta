defmodule Xpressbus.Cities.City do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cities" do
    field(:name, :string)
    field(:region, :string)
    field(:active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(city, attrs) do
    city
    |> cast(attrs, [:name, :region, :active])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
