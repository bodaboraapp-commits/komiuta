defmodule Xpressbus.Itineraries.SavedItinerary do
  @moduledoc """
  A trip brief saved from the Chyllz AI trip builder.

  Only the brief is persisted (destination, dates, travellers, budget and
  preferences); the display-ready itinerary is regenerated from it, so saved
  cards and the itinerary screen can never drift apart.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "saved_itineraries" do
    field(:title, :string)
    field(:destination, :string)
    field(:country, :string)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:travel_party, :string)
    field(:budget, :string)
    field(:preferences, :string, default: "[]")
    field(:art, :string, default: "mountains")
    field(:latitude, :float)
    field(:longitude, :float)
    field(:source, :string)

    belongs_to(:user, Xpressbus.Accounts.User, type: :binary_id)

    timestamps(type: :utc_datetime)
  end

  @fields ~w(
    user_id title destination country start_date end_date travel_party budget
    preferences art latitude longitude source
  )a

  @required ~w(user_id title destination art)a

  def changeset(saved_itinerary, attrs) do
    saved_itinerary
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> validate_length(:title, max: 160)
    |> validate_length(:destination, max: 80)
    |> validate_length(:country, max: 80)
    |> validate_inclusion(:art, ~w(mountains coast savanna))
  end
end
