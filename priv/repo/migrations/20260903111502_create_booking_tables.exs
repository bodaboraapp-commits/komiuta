defmodule Xpressbus.Repo.Migrations.CreateBookingTables do
  use Ecto.Migration

  def change do
    create table(:hotels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :price_per_night, :decimal
      add :rating, :decimal
      add :location, :string
      add :description, :text
      add :amenities, :json
      add :images, :json

      timestamps(type: :utc_datetime)
    end

    create table(:hidden_gems, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :location, :string
      add :description, :text
      add :images, :json

      timestamps(type: :utc_datetime)
    end

    create table(:car_hires, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :car_name, :string
      add :type, :string
      add :price_per_day, :decimal
      add :location, :string

      timestamps(type: :utc_datetime)
    end

    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :date, :date
      add :location, :string
      add :description, :text
      add :images, :json

      timestamps(type: :utc_datetime)
    end
  end
end
