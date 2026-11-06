defmodule Xpressbus.Repo.Migrations.AddAgentAuthentication do
  use Ecto.Migration

  def change do
    alter table(:agent_applications) do
      add :password_hash, :string
    end

    create unique_index(:agent_applications, [:email], name: :agent_applications_email_index)
    create index(:agent_applications, [:phone])
  end
end
