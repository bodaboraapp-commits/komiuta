defmodule Xpressbus.Repo.Migrations.AddMoneyPrecision do
  @moduledoc """
  Money columns were created as bare `:decimal` fields. On MySQL/MariaDB that
  defaults to `DECIMAL(10,0)`, so any fractional amount is rounded on write
  (for example a wallet balance of 120.50 is silently stored as 121).

  This migration gives every monetary column an explicit precision/scale so
  amounts round-trip exactly, and gives ratings a sensible 3,2 scale.
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      modify :wallet_balance, :decimal, precision: 12, scale: 2, default: 0
    end

    alter table(:coupons) do
      modify :value, :decimal, precision: 12, scale: 2
      modify :min_amount, :decimal, precision: 12, scale: 2, default: 0
      modify :max_discount, :decimal, precision: 12, scale: 2
    end

    alter table(:hotels) do
      modify :price_per_night, :decimal, precision: 12, scale: 2
      modify :rating, :decimal, precision: 3, scale: 2
    end

    alter table(:car_hires) do
      modify :price_per_day, :decimal, precision: 12, scale: 2
    end
  end

  def down do
    alter table(:users) do
      modify :wallet_balance, :decimal
    end

    alter table(:coupons) do
      modify :value, :decimal
      modify :min_amount, :decimal
      modify :max_discount, :decimal
    end

    alter table(:hotels) do
      modify :price_per_night, :decimal
      modify :rating, :decimal
    end

    alter table(:car_hires) do
      modify :price_per_day, :decimal
    end
  end
end
