defmodule Xpressbus.Repo.Migrations.AddBusOperatorToAgents do
  use Ecto.Migration

  # Bus operators are the partner list; each agent application can belong to one.
  def change do
    alter table(:agent_applications) do
      add :bus_operator_id, references(:bus_operators, on_delete: :nilify_all)
    end

    create index(:agent_applications, [:bus_operator_id])
  end
end
