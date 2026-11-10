defmodule Xpressbus.Repo.Migrations.CreateAnalyticsEvents do
  use Ecto.Migration

  def change do
    create table(:analytics_events) do
      add(:event, :string, null: false)
      add(:user_id, :binary_id)
      add(:metadata, :map)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create(index(:analytics_events, [:event, :inserted_at]))
    create(index(:analytics_events, [:inserted_at]))
  end
end
