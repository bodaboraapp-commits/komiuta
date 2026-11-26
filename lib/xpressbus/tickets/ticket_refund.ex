defmodule Xpressbus.Tickets.TicketRefund do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @statuses ~w(requested under_review approved processing refunded rejected retained withdrawn refund_pending)

  @open_statuses ~w(requested under_review approved processing refund_pending)

  schema "ticket_refunds" do
    field(:payment_id, :binary_id)
    field(:payment_confirmation_code, :string)
    field(:payment_reversal_code, :string)
    field(:ticket_id, :string)
    field(:amount, :integer)
    field(:amount_approved, :integer)
    field(:reason, :string)
    field(:reference, :string)
    field(:status, :string, default: "refunded")
    field(:resolution, :string, default: "refund")
    field(:admin_id, :integer)
    field(:customer_email, :string)
    field(:reviewed_by, :integer)
    field(:reviewed_at, :utc_datetime)
    field(:processed_at, :utc_datetime)
    field(:admin_note, :string)
    field(:credit_code, :string)
    field(:retention_offer, :string)
    field(:retention_accepted_at, :utc_datetime)
    field(:email_sent, :boolean, default: false)
    field(:sms_sent, :boolean, default: false)
    field(:notification_details, :map, default: %{})

    has_many(:events, Xpressbus.Tickets.TicketRefundEvent,
      foreign_key: :refund_id,
      preload_order: [asc: :inserted_at]
    )

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses
  def open_statuses, do: @open_statuses
  def open?(%__MODULE__{status: status}), do: status in @open_statuses

  @doc false
  def changeset(refund, attrs) do
    refund
    |> cast(attrs, [
      :ticket_id,
      :payment_id,
      :payment_confirmation_code,
      :payment_reversal_code,
      :amount,
      :amount_approved,
      :reason,
      :reference,
      :status,
      :resolution,
      :admin_id,
      :customer_email,
      :reviewed_by,
      :reviewed_at,
      :processed_at,
      :admin_note,
      :credit_code,
      :retention_offer,
      :retention_accepted_at,
      :email_sent,
      :sms_sent,
      :notification_details
    ])
    |> validate_required([:ticket_id, :amount])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, @statuses)
  end
end
