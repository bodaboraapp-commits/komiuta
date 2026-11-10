defmodule Xpressbus.HotelBookingsTest do
  use XpressbusWeb.ConnCase

  import Xpressbus.AccountsFixtures
  import Xpressbus.CatalogueFixtures

  alias Xpressbus.HotelBookings

  test "creates a reservation with snapshotted hotel details and total" do
    user = user_fixture()

    hotel =
      hotel_fixture(%{name: "Diani Beach House", location: "Diani", price_per_night: "12500"})

    check_in = Date.add(Date.utc_today(), 2)
    check_out = Date.add(check_in, 3)

    assert {:ok, booking} =
             HotelBookings.create_booking(user, hotel, %{
               "check_in" => Date.to_iso8601(check_in),
               "check_out" => Date.to_iso8601(check_out),
               "rooms" => "2",
               "guests" => "3"
             })

    assert booking.user_id == user.id
    assert booking.hotel_name == "Diani Beach House"
    assert booking.hotel_location == "Diani"
    assert booking.nights == 3
    assert booking.rooms == 2
    assert booking.guests == 3
    assert booking.status == "pending"
    assert Decimal.equal?(booking.price_per_night, Decimal.new("12500"))
    assert Decimal.equal?(booking.total_amount, Decimal.new("75000"))
    assert booking.reference =~ "STAY-"

    assert [listed] = HotelBookings.list_for_user(user.id)
    assert listed.id == booking.id
  end

  test "rejects invalid dates" do
    user = user_fixture()
    hotel = hotel_fixture()

    assert {:error, :invalid_dates} =
             HotelBookings.create_booking(user, hotel, %{
               "check_in" => "2026-12-10",
               "check_out" => "2026-12-08"
             })

    assert {:error, :past_check_in} =
             HotelBookings.create_booking(user, hotel, %{
               "check_in" => "2020-01-01",
               "check_out" => "2020-01-03"
             })
  end
end
