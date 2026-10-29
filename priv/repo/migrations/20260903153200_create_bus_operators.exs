defmodule Xpressbus.Repo.Migrations.CreateBusOperators do
  use Ecto.Migration

  def change do
    create table(:bus_operators) do
      add :name, :string, null: false
      add :contact_person, :string
      add :phone, :string
      add :email, :string
      add :active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bus_operators, [:name])
  end
end
