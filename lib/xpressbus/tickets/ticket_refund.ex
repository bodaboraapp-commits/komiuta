defmodule Xpressbus.Tickets.TicketRefund do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "ticket_refunds" do
    field(:ticket_id, :string)
    field(:amount, :integer)
    field(:reason, :string)
    field(:reference, :string)
    field(:status, :string, default: "refunded")
    field(:admin_id, :integer)
    field(:email_sent, :boolean, default: false)
    field(:sms_sent, :boolean, default: false)
    field(:notification_details, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(refund, attrs) do
    refund
    |> cast(attrs, [
      :ticket_id,
      :amount,
      :reason,
      :reference,
      :status,
      :admin_id,
      :email_sent,
      :sms_sent,
      :notification_details
    ])
    |> validate_required([:ticket_id, :amount])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, ["refunded", "refund_pending"])
  end
end
