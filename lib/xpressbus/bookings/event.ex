defmodule Xpressbus.Bookings.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "events" do
    field(:title, :string)
    field(:date, :date)
    field(:location, :string)
    field(:description, :string)
    field(:images, {:array, :string}, default: [])

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :date, :location, :description, :images])
    |> validate_required([:title, :date, :location])
  end
end
