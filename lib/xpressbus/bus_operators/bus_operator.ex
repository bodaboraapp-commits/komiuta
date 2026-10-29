defmodule Xpressbus.BusOperators.BusOperator do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bus_operators" do
    field(:name, :string)
    field(:contact_person, :string)
    field(:phone, :string)
    field(:email, :string)
    field(:active, :boolean, default: true)
    field(:logo_url, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(bus_operator, attrs) do
    bus_operator
    |> cast(attrs, [:name, :contact_person, :phone, :email, :active, :logo_url])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
