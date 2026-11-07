defmodule Xpressbus.Repo.Migrations.AddBookingScopeToAgentApplications do
  use Ecto.Migration

  def change do
    alter table(:agent_applications) do
      add(:booking_scope, :string, null: false, default: "all")
      add(:booking_from, :string)
      add(:booking_to, :string)
    end
  end
end
