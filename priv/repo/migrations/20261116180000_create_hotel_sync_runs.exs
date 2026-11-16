defmodule Xpressbus.Repo.Migrations.CreateHotelSyncRuns do
  use Ecto.Migration

  def change do
    create table(:hotel_sync_runs) do
      add :status, :string, null: false
      add :hotels_count, :integer, null: false, default: 0
      add :matched_count, :integer, null: false, default: 0
      add :details, :text

      timestamps(type: :utc_datetime)
    end

    create index(:hotel_sync_runs, [:inserted_at])
  end
end
