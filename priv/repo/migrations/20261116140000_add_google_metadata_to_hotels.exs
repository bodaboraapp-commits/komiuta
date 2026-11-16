defmodule Xpressbus.Repo.Migrations.AddGoogleMetadataToHotels do
  use Ecto.Migration

  def change do
    alter table(:hotels) do
      add(:google_place_id, :string)
      add(:google_maps_url, :string)
      add(:google_photo_ref, :string)
      add(:formatted_address, :string)
      add(:review_count, :integer)
      add(:google_synced_at, :utc_datetime)
    end

    create(index(:hotels, [:google_place_id]))
  end
end
