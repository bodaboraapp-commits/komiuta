defmodule Xpressbus.Repo.Migrations.CreatePayments do
  @moduledoc false

  use Ecto.Migration

  def change do
    create table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :amount, :integer, null: false
      add :currency, :string, default: "KES", null: false
      add :status, :string, default: "pending", null: false
      add :reference, :string, null: false
      add :phone_number, :string, null: false
      add :ticket_id, :string
      add :raw_response, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:reference])
  end
end
