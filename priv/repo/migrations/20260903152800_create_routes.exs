defmodule Xpressbus.Repo.Migrations.CreateRoutes do
  use Ecto.Migration

  def change do
    create table(:routes) do
      add :origin, :string, null: false
      add :destination, :string, null: false
      add :distance, :string
      add :duration, :string
      add :active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:routes, [:origin, :destination])
  end
end
