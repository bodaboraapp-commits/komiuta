defmodule Xpressbus.Repo.Migrations.CreateEmailChangeCodes do
  use Ecto.Migration

  def change do
    create table(:email_change_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :new_email, :string, null: false
      add :code_digest, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, default: 0, null: false
      add :consumed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:email_change_codes, [:user_id])
  end
end
