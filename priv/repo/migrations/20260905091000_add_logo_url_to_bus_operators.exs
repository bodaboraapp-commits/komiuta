defmodule Xpressbus.Repo.Migrations.AddLogoUrlToBusOperators do
  use Ecto.Migration

  def change do
    alter table(:bus_operators) do
      add(:logo_url, :string)
    end
  end
end
