defmodule Xpressbus.Repo.Migrations.CreateFacilities do
  use Ecto.Migration

  def change do
    create table(:facilities) do
      add :name, :string, null: false
      add :icon, :string
      add :description, :string
      add :active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:facilities, [:name])
  end
end
