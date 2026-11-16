defmodule Xpressbus.Repo.Migrations.RenameSandsHotelToNomad do
  use Ecto.Migration

  def up do
    # "The Sands Resort" has no direct Google listing in Diani; its real
    # counterpart on Google is Nomad Beach Resort. Rename it and clear any
    # previous Google metadata so enrichment runs again.
    execute("""
    UPDATE hotels
    SET name = 'Nomad Beach Resort',
        description = 'Boutique beachfront resort.',
        google_synced_at = NULL,
        google_place_id = NULL,
        google_photo_ref = NULL,
        google_maps_url = NULL,
        formatted_address = NULL,
        review_count = NULL
    WHERE name = 'The Sands Resort'
    """)
  end

  def down do
    execute("UPDATE hotels SET name = 'The Sands Resort' WHERE name = 'Nomad Beach Resort'")
  end
end
