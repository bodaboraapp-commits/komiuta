defmodule Xpressbus.Bookings.HotelGoogleTest do
  use Xpressbus.DataCase, async: false

  import Xpressbus.CatalogueFixtures

  alias Xpressbus.Bookings.HotelGoogle
  alias Xpressbus.{GooglePlaces, Repo}

  setup do
    previous = Application.get_env(:xpressbus, :hotel_google_lookup_override)

    on_exit(fn ->
      if previous do
        Application.put_env(:xpressbus, :hotel_google_lookup_override, previous)
      else
        Application.delete_env(:xpressbus, :hotel_google_lookup_override)
      end
    end)

    :ok
  end

  test "stores real Google photos, ratings and review counts on the hotel" do
    Application.put_env(:xpressbus, :hotel_google_lookup_override, fn _name, _location ->
      {:ok,
       %{
         id: "place-1",
         rating: 4.6,
         reviews: 1_234,
         photo_ref: "places/place-1/photos/photo-2",
         maps_url: "https://maps.google.com/?cid=1",
         address: "Diani Beach, Kenya"
       }}
    end)

    hotel = hotel_fixture(%{name: "The Sands Resort", location: "Diani"})
    [enriched] = HotelGoogle.enrich([hotel], force: true)

    assert enriched.review_count == 1_234
    assert enriched.formatted_address == "Diani Beach, Kenya"
    assert enriched.google_maps_url == "https://maps.google.com/?cid=1"
    assert enriched.google_place_id == "place-1"
    assert enriched.google_photo_ref == "places/place-1/photos/photo-2"

    assert enriched.images == [
             GooglePlaces.photo_proxy_path("places/place-1/photos/photo-2")
           ]

    reloaded = Repo.reload!(hotel)
    assert Decimal.to_float(reloaded.rating) == 4.6
    assert reloaded.review_count == 1_234
    assert reloaded.google_synced_at
  end

  test "keeps the curated fallback when Google has no confident match" do
    Application.put_env(:xpressbus, :hotel_google_lookup_override, fn _name, _location ->
      {:error, :no_confident_match}
    end)

    hotel = hotel_fixture(%{name: "Unlisted Stay"})
    [result] = HotelGoogle.enrich([hotel], force: true)

    assert result.images == []
    assert result.review_count == nil
    assert Repo.reload!(hotel).google_synced_at
  end

  test "does not call Google again while the stored data is fresh" do
    Application.put_env(:xpressbus, :hotel_google_lookup_override, fn _name, _location ->
      raise "Google should not be called while data is fresh"
    end)

    hotel = hotel_fixture(%{})
    synced_at = DateTime.utc_now() |> DateTime.truncate(:second)
    hotel = Repo.update!(Ecto.Changeset.change(hotel, google_synced_at: synced_at))

    assert [result] = HotelGoogle.enrich([hotel])
    assert result.id == hotel.id
  end
end
