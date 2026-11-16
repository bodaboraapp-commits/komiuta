defmodule Xpressbus.Repo.Migrations.SeedKenyaHiddenGems do
  use Ecto.Migration

  alias Xpressbus.Bookings.HiddenGem
  alias Xpressbus.Bookings.HiddenGemSeedData

  def up do
    # The old Diani entry was a retreat; it is now the island itself.
    case repo().get_by(HiddenGem, title: "Chale Island Retreat") do
      nil ->
        :ok

      old ->
        if repo().get_by(HiddenGem, title: "Chale Island") do
          :ok
        else
          old |> Ecto.Changeset.change(title: "Chale Island") |> repo().update!()
        end
    end

    Enum.each(HiddenGemSeedData.kenya_gems(), fn attrs ->
      case repo().get_by(HiddenGem, title: attrs.title) do
        nil ->
          %HiddenGem{} |> HiddenGem.changeset(attrs) |> repo().insert!()

        gem ->
          gem |> HiddenGem.changeset(attrs) |> repo().update!()
      end
    end)
  end

  def down do
    :ok
  end
end
