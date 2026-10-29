defmodule Xpressbus.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :phone, :string
      add :email, :string
      add :wallet_balance, :decimal
      add :avatar_url, :string
      add :default_payment_method, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:phone])
  end
end
