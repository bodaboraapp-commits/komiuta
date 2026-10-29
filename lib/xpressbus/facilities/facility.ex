defmodule Xpressbus.Facilities.Facility do
  use Ecto.Schema
  import Ecto.Changeset

  schema "facilities" do
    field(:name, :string)
    field(:icon, :string)
    field(:description, :string)
    field(:active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(facility, attrs) do
    facility
    |> cast(attrs, [:name, :icon, :description, :active])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
