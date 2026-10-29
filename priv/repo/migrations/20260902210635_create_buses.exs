defmodule Xpressbus.Repo.Migrations.CreateBuses do
  use Ecto.Migration

  def change do
    create table(:buses) do
      add :company, :string
      add :departure, :string
      add :arrival, :string
      add :seats, :string
      add :price, :string
      add :registration, :string
      add :from, :string
      add :to, :string
      add :duration, :string
      add :rating, :string
      add :vip_price, :string
      add :business_price, :string
      add :amenities, :json
      add :seat_types, :json
      add :occupied_seats, :json
      add :total_seats, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
