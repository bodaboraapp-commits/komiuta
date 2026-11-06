defmodule Xpressbus.Repo.Migrations.AddEmailVerifiedAtToAgentApplications do
  use Ecto.Migration

  def change do
    alter table(:agent_applications) do
      add :email_verified_at, :utc_datetime
    end
  end
end
