defmodule Xpressbus.Tickets.TicketRefundEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "ticket_refund_events" do
    field(:refund_id, :binary_id)
    field(:status, :string)
    field(:actor_type, :string, default: "system")
    field(:actor_id, :string)
    field(:note, :string)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:refund_id, :status, :actor_type, :actor_id, :note, :metadata])
    |> validate_required([:refund_id, :status, :actor_type])
    |> validate_inclusion(:actor_type, ["customer", "admin", "system"])
  end
end
