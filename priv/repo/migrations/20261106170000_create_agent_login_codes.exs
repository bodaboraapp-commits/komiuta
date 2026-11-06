defmodule Xpressbus.Repo.Migrations.CreateAgentLoginCodes do
  @moduledoc """
  One-time email codes used to sign in to the KOMIUTA Agent PWA.

  Only a keyed digest of the code is stored (never the code itself), together
  with an expiry, attempt counter and consumption timestamp.
  """

  use Ecto.Migration

  def change do
    create table(:agent_login_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :agent_application_id,
          references(:agent_applications, type: :binary_id, on_delete: :delete_all),
          null: false

      add :code_digest, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, default: 0, null: false
      add :consumed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:agent_login_codes, [:agent_application_id])
    create index(:agent_login_codes, [:expires_at])
  end
end
