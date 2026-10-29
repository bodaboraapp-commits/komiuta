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

    timestamps(type: :utc_datetime)
  end

  def changeset(hidden_gem, attrs) do
    hidden_gem
    |> cast(attrs, [:title, :location, :description, :images, :active])
    |> validate_required([:title, :location])
    |> unique_constraint(:title)
  end
end
