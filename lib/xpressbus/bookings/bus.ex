defmodule Xpressbus.Bookings.Bus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "buses" do
    field(:company, :string)
    field(:departure, :string)
    field(:arrival, :string)
    field(:seats, :string)
    field(:price, :string)
    field(:registration, :string)
    field(:from, :string)
    field(:to, :string)
    field(:travel_date, :date)
    field(:duration, :string, default: "10h 30m")
    field(:rating, :string, default: "4.8")
    field(:vip_price, :string, default: "KSH 2,300")
    field(:business_price, :string, default: "KSH 2,000")
    field(:first_class_price, :string, default: "KSH 1,800")
    field(:amenities, {:array, :string}, default: ["AC", "Charging", "Wi-Fi"])
    field(:seat_types, {:array, :string}, default: ["Normal", "Vip", "Business"])
    field(:occupied_seats, {:array, :string}, default: [])
    field(:total_seats, :integer, default: 40)
    field(:logo_url, :string, virtual: true)

    belongs_to(:bus_operator, Xpressbus.BusOperators.BusOperator)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bus, attrs) do
    bus
    |> cast(attrs, [
      :company,
      :departure,
      :arrival,
      :seats,
      :price,
      :registration,
      :from,
      :to,
      :travel_date,
      :duration,
      :rating,
      :vip_price,
      :business_price,
      :first_class_price,
      :amenities,
      :seat_types,
      :occupied_seats,
      :total_seats,
      :bus_operator_id
    ])
    |> validate_required([:company, :departure, :arrival, :from, :to, :travel_date])
    |> unique_constraint(:unique_bus_trip, name: :unique_bus_trip)
    |> foreign_key_constraint(:bus_operator_id)
  end
end
