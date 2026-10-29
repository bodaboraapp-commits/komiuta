defmodule Xpressbus.Repo.Migrations.ShortenBusKeyColumns do
  @moduledoc """
  MySQL 8 / InnoDB with utf8mb4 limits an index key to 3072 bytes.
  `unique_bus_trip` spans five columns; at the default varchar(255) it exceeds
  that limit ("Specified key was too long"). Shrink the four string key columns
  so the composite index fits on MySQL 8 as well as MariaDB.

  Runs between CreateBuses and SyncBusesTable (where the index is created).
  """

  use Ecto.Migration

  def up do
    alter table(:buses) do
      modify :company, :string, size: 120
      modify :departure, :string, size: 40
      modify :from, :string, size: 80
      modify :to, :string, size: 80
    end
  end

  def down do
    alter table(:buses) do
      modify :company, :string
      modify :departure, :string
      modify :from, :string
      modify :to, :string
    end
  end
end
