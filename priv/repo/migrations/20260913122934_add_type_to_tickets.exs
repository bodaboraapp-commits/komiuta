defmodule Xpressbus.Repo.Migrations.AddTypeToTickets do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add :type, :string, default: "One-Way Ticket"
    end
  end
end
