defmodule Xpressbus.Repo.Migrations.CreateTickets do
  use Ecto.Migration

  def change do
    create table(:tickets) do
      add :ticket_id, :string
      add :from, :string
      add :to, :string
      add :travel_date, :date
      add :departure, :string
      add :arrival, :string
      add :company, :string
      add :price, :string
      add :seats, :text
      add :passenger_name, :string
      add :passenger_phone, :string
      add :payment_method, :string
      add :status, :string, default: "confirmed"
      add :bus_id, references(:buses, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:tickets, [:ticket_id], unique: true)
    create index(:tickets, [:bus_id])
  end
end
