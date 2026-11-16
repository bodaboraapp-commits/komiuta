defmodule Xpressbus.Repo.Migrations.AddHiddenGemMetadata do
  use Ecto.Migration

  def change do
    alter table(:hidden_gems) do
      add(:category, :string)
      add(:region, :string)
      add(:best_time, :string)
      add(:entry_fee, :string)
      add(:access_notes, :string)
      add(:website_url, :string)
      add(:source_url, :text)
      add(:source_checked_at, :utc_datetime)
      add(:latitude, :float)
      add(:longitude, :float)
      add(:google_place_id, :string)
      add(:google_maps_url, :text)
      add(:google_photo_ref, :text)
      add(:formatted_address, :text)
      add(:rating, :decimal, precision: 5, scale: 1)
      add(:review_count, :integer)
      add(:google_synced_at, :utc_datetime)
    end

    create(index(:hidden_gems, [:google_place_id]))
    create(index(:hidden_gems, [:region]))

    alter table(:hotel_sync_runs) do
      add(:gems_count, :integer, null: false, default: 0)
      add(:gems_matched_count, :integer, null: false, default: 0)
    end
  end
end
