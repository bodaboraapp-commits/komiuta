defmodule Xpressbus.Repo.Migrations.AddRelationsToTransportTables do
  use Ecto.Migration

  def change do
    alter table(:buses) do
      add(:bus_operator_id, references(:bus_operators, on_delete: :nilify_all))
    end

    create(index(:buses, [:bus_operator_id]))

    alter table(:drop_pick_points) do
      add(:city_id, references(:cities, on_delete: :nilify_all))
    end

    create(index(:drop_pick_points, [:city_id]))

    alter table(:routes) do
      add(:origin_city_id, references(:cities, on_delete: :nilify_all))
      add(:destination_city_id, references(:cities, on_delete: :nilify_all))
    end

    create(index(:routes, [:origin_city_id]))
    create(index(:routes, [:destination_city_id]))
  end
end
