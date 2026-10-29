defmodule Xpressbus.Repo.Migrations.DropMpesaSettings do
  use Ecto.Migration

  def change do
    drop table(:mpesa_settings)
  end
end
