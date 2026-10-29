defmodule Xpressbus.Repo.Migrations.AddUserReferralsAndTransactions do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :referral_code, :string
      add :referred_by_id, references(:users, type: :binary_id, on_delete: :nothing)
      add :points_balance, :integer, default: 0
    end

    create unique_index(:users, [:referral_code])

    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :type, :string, null: false # e.g., "credit", "debit"
      add :status, :string, null: false # e.g., "completed", "pending", "failed"
      add :description, :string
      add :reference_id, :string # e.g., M-Pesa code

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:reference_id])
  end
end
