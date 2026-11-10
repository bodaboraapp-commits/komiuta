defmodule Xpressbus.Repo.Migrations.CreateHotelBookings do
  use Ecto.Migration

  def change do
    create table(:hotel_bookings, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:reference, :string, null: false)
      add(:hotel_id, references(:hotels, type: :binary_id, on_delete: :nilify_all))
      add(:hotel_name, :string)
      add(:hotel_location, :string)
      add(:user_id, references(:users, type: :binary_id, on_delete: :nilify_all))
      add(:guest_name, :string)
      add(:guest_phone, :string)
      add(:guest_email, :string)
      add(:check_in, :date)
      add(:check_out, :date)
      add(:nights, :integer, default: 1)
      add(:rooms, :integer, default: 1)
      add(:guests, :integer, default: 1)
      add(:price_per_night, :decimal, precision: 12, scale: 2)
      add(:total_amount, :decimal, precision: 12, scale: 2)
      add(:status, :string, default: "pending")
      add(:notes, :text)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:hotel_bookings, [:reference]))
    create(index(:hotel_bookings, [:user_id]))
    create(index(:hotel_bookings, [:hotel_id]))
  end
end
