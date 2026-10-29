defmodule Xpressbus.Repo.Migrations.CreateCoupons do
  use Ecto.Migration

  def change do
    create table(:coupons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string
      add :type, :string
      add :value, :decimal
      add :min_amount, :decimal
      add :max_discount, :decimal
      add :expiry_date, :date
      add :usage_limit, :integer
      add :usage_count, :integer
      add :active, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:coupons, [:code])
  end
end
