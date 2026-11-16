defmodule Xpressbus.Repo.Migrations.SeedKenyaHotels do
  use Ecto.Migration
  import Ecto.Query

  def up do
    existing = repo().all(from(h in "hotels", select: h.name)) |> MapSet.new()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Xpressbus.Bookings.HotelSeedData.kenya_hotels()
      |> Enum.reject(&MapSet.member?(existing, &1.name))
      |> Enum.map(fn attrs ->
        Map.merge(
          %{id: Ecto.UUID.generate(), active: true, inserted_at: now, updated_at: now},
          attrs
        )
      end)

    repo().insert_all(Xpressbus.Bookings.Hotel, rows, on_conflict: :nothing)
  end

  def down do
    names = Enum.map(Xpressbus.Bookings.HotelSeedData.kenya_hotels(), & &1.name)
    repo().delete_all(from(h in "hotels", where: h.name in ^names))
  end
end
