defmodule Xpressbus.Bookings.HotelSeedDataTest do
  use ExUnit.Case, async: true

  alias Xpressbus.Bookings.HotelSeedData

  test "the curated catalogue has 15-25 unique Kenyan hotels with Google metadata" do
    hotels = HotelSeedData.kenya_hotels()

    assert length(hotels) in 15..25
    names = Enum.map(hotels, & &1.name)
    assert length(Enum.uniq(names)) == length(names)

    locations = hotels |> Enum.map(& &1.location) |> Enum.uniq()
    assert length(locations) >= 8

    for hotel <- hotels do
      assert is_binary(hotel.google_place_id) and hotel.google_place_id != ""
      assert is_integer(hotel.review_count) and hotel.review_count > 0
      assert is_float(hotel.rating) or is_integer(hotel.rating)
      assert [image | _] = hotel.images
      assert String.starts_with?(image, "/places/photo?ref=")
    end
  end
end
