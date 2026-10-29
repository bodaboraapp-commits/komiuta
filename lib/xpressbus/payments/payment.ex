defmodule Xpressbus.Payments.Payment do
  @moduledoc """
  Tracks an outbound payment attempt tied to a booking flow.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "payments" do
    field(:provider, :string)
    field(:amount, :integer)
    field(:currency, :string, default: "KES")
    field(:status, :string, default: "pending")
    field(:reference, :string)
    field(:phone_number, :string)
    field(:ticket_id, :string)
    field(:raw_response, :map)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      :provider,
      :amount,
      :currency,
      :status,
      :reference,
      :phone_number,
      :ticket_id,
      :raw_response
    ])
    |> validate_required([:provider, :amount, :reference])
    |> validate_inclusion(:status, ["pending", "success", "failed", "cancelled"])
  end
end
