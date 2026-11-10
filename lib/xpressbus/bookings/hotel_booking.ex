defmodule Xpressbus.Bookings.HotelBooking do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "hotel_bookings" do
    field(:reference, :string)
    field(:hotel_name, :string)
    field(:hotel_location, :string)
    field(:guest_name, :string)
    field(:guest_phone, :string)
    field(:guest_email, :string)
    field(:check_in, :date)
    field(:check_out, :date)
    field(:nights, :integer, default: 1)
    field(:rooms, :integer, default: 1)
    field(:guests, :integer, default: 1)
    field(:price_per_night, :decimal)
    field(:total_amount, :decimal)
    field(:status, :string, default: "pending")
    field(:notes, :string)

    belongs_to(:hotel, Xpressbus.Bookings.Hotel)
    belongs_to(:user, Xpressbus.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [
      :reference,
      :hotel_id,
      :hotel_name,
      :hotel_location,
      :user_id,
      :guest_name,
      :guest_phone,
      :guest_email,
      :check_in,
      :check_out,
      :nights,
      :rooms,
      :guests,
      :price_per_night,
      :total_amount,
      :status,
      :notes
    ])
    |> validate_required([
      :reference,
      :guest_name,
      :guest_phone,
      :check_in,
      :check_out,
      :nights,
      :rooms,
      :guests,
      :status
    ])
    |> validate_number(:nights, greater_than: 0)
    |> validate_number(:rooms, greater_than: 0)
    |> validate_number(:guests, greater_than: 0)
    |> validate_status()
    |> unique_constraint(:reference)
  end

  defp validate_status(changeset) do
    validate_inclusion(changeset, :status, ["pending", "confirmed", "cancelled", "completed"])
  end
end
