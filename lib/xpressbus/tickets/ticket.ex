defmodule Xpressbus.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tickets" do
    field(:ticket_id, :string)
    field(:from, :string)
    field(:to, :string)
    field(:travel_date, :date)
    field(:departure, :string)
    field(:arrival, :string)
    field(:company, :string)
    field(:price, :string)
    field(:seats, :string)
    field(:passenger_name, :string)
    field(:passenger_phone, :string)
    field(:payment_method, :string)
    field(:status, :string)
    field(:type, :string)
    field(:cancelled_at, :utc_datetime)
    field(:cancellation_reason, :string)
    field(:refund_amount, :integer)
    field(:refund_reference, :string)

    belongs_to(:bus, Xpressbus.Bookings.Bus)

    timestamps(type: :utc_datetime)
  end

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [
      :ticket_id,
      :from,
      :to,
      :travel_date,
      :departure,
      :arrival,
      :company,
      :price,
      :seats,
      :passenger_name,
      :passenger_phone,
      :payment_method,
      :status,
      :bus_id,
      :type,
      :cancelled_at,
      :cancellation_reason,
      :refund_amount,
      :refund_reference
    ])
    |> validate_required([:ticket_id, :from, :to, :travel_date, :company, :price, :seats])
    |> unique_constraint(:ticket_id)
  end
end
