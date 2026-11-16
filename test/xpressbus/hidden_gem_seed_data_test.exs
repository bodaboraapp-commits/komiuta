defmodule Xpressbus.Bookings.HiddenGemSeedDataTest do
  use ExUnit.Case, async: true

  alias Xpressbus.Bookings.HiddenGemSeedData

  test "the curated hidden gems meet the selection criteria" do
    gems = HiddenGemSeedData.kenya_gems()

    assert length(gems) in 15..25
    titles = Enum.map(gems, & &1.title)
    assert length(Enum.uniq(titles)) == length(titles)

    assert gems |> Enum.map(& &1.region) |> Enum.uniq() |> length() >= 5
    assert gems |> Enum.map(& &1.category) |> Enum.uniq() |> length() >= 4
    assert Enum.all?(gems, fn gem -> is_binary(gem.google_place_id) and gem.google_place_id != "" end)
    assert Enum.all?(gems, fn gem -> is_binary(gem.description) and gem.description != "" end)
    assert Enum.all?(gems, fn gem -> is_binary(gem.access_notes) and gem.access_notes != "" end)

    with_images = Enum.count(gems, fn gem -> gem.images != [] end)
    assert with_images >= length(gems) - 2
  end
end
