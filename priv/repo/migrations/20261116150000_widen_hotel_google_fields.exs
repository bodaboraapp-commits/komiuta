defmodule Xpressbus.Repo.Migrations.WidenHotelGoogleFields do
  use Ecto.Migration

  def change do
    alter table(:hotels) do
      modify(:google_photo_ref, :text)
      modify(:google_maps_url, :text)
      modify(:formatted_address, :text)
    end
  end
end
