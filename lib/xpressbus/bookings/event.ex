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
    field(:active, :boolean, default: true)

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :date, :location, :description, :images, :active])
    |> validate_required([:title, :date, :location])
    |> unique_constraint(:title, name: :events_title_date_index)
  end
end
