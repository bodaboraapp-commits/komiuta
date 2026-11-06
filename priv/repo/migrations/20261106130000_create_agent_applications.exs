defmodule Xpressbus.Repo.Migrations.CreateAgentApplications do
  use Ecto.Migration

  def change do
    create table(:agent_applications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reference, :string, null: false
      add :full_name, :string, null: false
      add :email, :string, null: false
      add :phone, :string, null: false
      add :business_name, :string
      add :city, :string
      add :routes, :text
      add :payout_method, :string, default: "mpesa"
      add :notes, :text
      add :status, :string, default: "pending"
      add :admin_notes, :text
      add :reviewed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:agent_applications, [:reference])
    create index(:agent_applications, [:status])
    create index(:agent_applications, [:inserted_at])
  end
end
