defmodule Xpressbus.Repo.Migrations.CreateLoginCodes do
  @moduledoc """
  One-time email login codes.

  Only a keyed digest of the code is stored (never the code itself), together
  with an expiry, an attempt counter and the consumption timestamp.
  """

  use Ecto.Migration

  def change do
    create table(:login_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :code_digest, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, default: 0, null: false
      add :consumed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:login_codes, [:user_id])
    create index(:login_codes, [:expires_at])
  end
end
