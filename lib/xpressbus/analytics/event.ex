defmodule Xpressbus.Analytics.Event do
  @moduledoc """
  A first-party funnel event.

  Events are intentionally small and privacy-conscious: an event name, an
  optional user id and optional non-personal metadata. They power the admin
  funnel report and are never rendered on customer-facing pages.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "analytics_events" do
    field(:event, :string)
    field(:user_id, :binary_id)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @fields ~w(event user_id metadata)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, @fields)
    |> validate_required([:event])
    |> validate_length(:event, max: 80)
  end
end
