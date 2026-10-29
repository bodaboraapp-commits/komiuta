defmodule Xpressbus.Repo.Migrations.CreateDropPickPoints do
  use Ecto.Migration

  def change do
    create table(:drop_pick_points) do
      add :name, :string, null: false
      add :location, :string
      add :city, :string
      add :active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:drop_pick_points, [:name])
  end
end
