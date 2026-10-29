defmodule Xpressbus.Repo.Migrations.SyncBusesTable do
  use Ecto.Migration

  def change do
    alter table(:buses) do
      add :travel_date, :date
    end

    # Identification index for avoiding duplicates during bulk pull and syncing updates
    create unique_index(:buses, [:company, :departure, :from, :to, :travel_date], name: :unique_bus_trip)
  end
end
