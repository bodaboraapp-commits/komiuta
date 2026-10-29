defmodule Xpressbus.Repo.Migrations.AddFirstClassPriceToBuses do
  use Ecto.Migration

  def change do
    alter table(:buses) do
      add(:first_class_price, :string, default: "KSH 1,800", null: false)
    end
  end
end