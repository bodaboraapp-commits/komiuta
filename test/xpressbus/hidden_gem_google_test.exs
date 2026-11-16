defmodule Xpressbus.Bookings.HiddenGemGoogleTest do
  use Xpressbus.DataCase, async: false

  import Xpressbus.CatalogueFixtures

  alias Xpressbus.Bookings.{HiddenGem, HiddenGemGoogle}
  alias Xpressbus.{GooglePlaces, Repo}

  setup do
    previous = Application.get_env(:xpressbus, :hidden_gem_google_lookup_override)

    on_exit(fn ->
      if previous do
        Application.put_env(:xpressbus, :hidden_gem_google_lookup_override, previous)
      else
        Application.delete_env(:xpressbus, :hidden_gem_google_lookup_override)
      end
    end)

    :ok
  end

  test "stores the real Google photo, rating and coordinates on the gem" do
    photo_ref = "places/gem/photos/" <> String.duplicate("p", 80)

    Application.put_env(:xpressbus, :hidden_gem_google_lookup_override, fn _title, _location ->
      {:ok,
       %{
         id: "gem-place-1",
         rating: 4.7,
         reviews: 456,
         photo_ref: photo_ref,
         maps_url: "https://maps.google.com/?cid=1",
         address: "Naivasha, Kenya",
         latitude: -0.8,
         longitude: 36.4,
         website: "https://example.com/gem"
       }}
    end)

    gem = hidden_gem_fixture(%{title: "Mount Test", location: "Naivasha"})
    [enriched] = HiddenGemGoogle.enrich([gem], force: true)

    assert enriched.google_place_id == "gem-place-1"
    assert enriched.review_count == 456
    assert enriched.formatted_address == "Naivasha, Kenya"
    assert enriched.google_photo_ref == photo_ref
    assert enriched.website_url == "https://example.com/gem"
    assert enriched.latitude == -0.8

    reloaded = Repo.get!(HiddenGem, gem.id)
    assert Decimal.to_float(reloaded.rating) == 4.7
    assert reloaded.images == [GooglePlaces.photo_proxy_path(photo_ref)]
    assert reloaded.google_synced_at
  end

  test "keeps curated fields when Google has no match" do
    Application.put_env(:xpressbus, :hidden_gem_google_lookup_override, fn _title, _location ->
      {:error, :no_confident_match}
    end)

    gem = hidden_gem_fixture(%{title: "Unlisted Gem", location: "Kenya"})
    [result] = HiddenGemGoogle.enrich([gem], force: true)

    assert result.images == []
    assert result.review_count == nil
    assert Repo.reload!(gem).google_synced_at
  end
end
