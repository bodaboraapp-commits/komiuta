defmodule Xpressbus.GoogleHotelSyncTest do
  use Xpressbus.DataCase, async: false

  import Xpressbus.CatalogueFixtures

  alias Xpressbus.Bookings.{Hotel, HotelSyncRun}
  alias Xpressbus.{GoogleHotelSync, HotelSyncEmail, Repo}

  setup do
    previous_lookup = Application.get_env(:xpressbus, :hotel_google_lookup_override)

    on_exit(fn ->
      if previous_lookup do
        Application.put_env(:xpressbus, :hotel_google_lookup_override, previous_lookup)
      else
        Application.delete_env(:xpressbus, :hotel_google_lookup_override)
      end
    end)

    :ok
  end

  test "refreshes all active hotels, records the run and is then fresh" do
    Application.put_env(:xpressbus, :hotel_google_lookup_override, fn name, _location ->
      {:ok,
       %{
         id: "place-" <> name,
         rating: 4.5,
         reviews: 321,
         photo_ref: "places/#{name}/photos/one",
         maps_url: "https://maps.google.com/?cid=1",
         address: "Nairobi, Kenya"
       }}
    end)

    hotel = hotel_fixture(%{name: "Sarova Stanley", location: "Nairobi"})

    assert {:ok, run} = GoogleHotelSync.run(force: true)
    assert run.status == "success"
    assert run.hotels_count == 1
    assert run.matched_count == 1

    reloaded = Repo.get!(Hotel, hotel.id)
    assert reloaded.google_place_id == "place-Sarova Stanley"
    assert reloaded.review_count == 321

    assert GoogleHotelSync.due?() == false
    assert {:skipped, :fresh} = GoogleHotelSync.run()
  end

  test "marks a run failed when no hotel matches and becomes due again after two days" do
    Application.put_env(:xpressbus, :hotel_google_lookup_override, fn _name, _location ->
      {:error, :no_confident_match}
    end)

    hotel_fixture(%{name: "No Google Match Stay"})

    assert {:ok, run} = GoogleHotelSync.run(force: true)
    assert run.status == "failed"
    assert run.matched_count == 0

    assert Repo.aggregate(HotelSyncRun, :count, :id) == 1
    assert GoogleHotelSync.due?() == false

    run
    |> Ecto.Changeset.change(
      inserted_at:
        DateTime.add(DateTime.utc_now(), -3 * 86_400, :second) |> DateTime.truncate(:second)
    )
    |> Repo.update!()

    assert GoogleHotelSync.due?() == true
  end

  test "report email addresses the operations inbox with the run outcome" do
    run = %HotelSyncRun{
      status: "success",
      hotels_count: 2,
      matched_count: 2,
      details: "A: matched\nB: matched",
      inserted_at: DateTime.utc_now()
    }

    email = HotelSyncEmail.build(run)

    assert email.subject =~ "success"
    assert Enum.any?(email.to, fn {_name, address} -> address == "komondiedward@gmail.com" end)
    assert email.text_body =~ "Hotels checked: 2"
    assert email.html_body =~ "logo_email.png"
    assert email.html_body =~ "Follow us"
    assert email.html_body =~ "Operations report"
  end

  test "the report falls back to the default inbox when the alert email is blank" do
    previous = Application.get_env(:xpressbus, :hotel_sync_alert_email)
    Application.put_env(:xpressbus, :hotel_sync_alert_email, "")

    on_exit(fn ->
      if previous do
        Application.put_env(:xpressbus, :hotel_sync_alert_email, previous)
      else
        Application.delete_env(:xpressbus, :hotel_sync_alert_email)
      end
    end)

    run = %HotelSyncRun{
      status: "success",
      hotels_count: 1,
      matched_count: 1,
      inserted_at: DateTime.utc_now()
    }

    email = HotelSyncEmail.build(run)

    assert Enum.any?(email.to, fn {_name, address} -> address == "komondiedward@gmail.com" end)
  end
end
