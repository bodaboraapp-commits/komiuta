defmodule XpressbusWeb.ChyllzStayBookingTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures
  import Xpressbus.CatalogueFixtures

  alias Xpressbus.HotelBookings

  defp signed_in(conn, user), do: Plug.Test.init_test_session(conn, %{user_id: user.id})

  test "a signed-in traveller can reserve a stay from the hotel dialog", %{conn: conn} do
    user = user_fixture()
    hotel = hotel_fixture(%{name: "Diani Sands Test", location: "Diani"})
    check_in = Date.add(Date.utc_today(), 3)

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/tour-packages/hotels")

    view |> element("#hotel-card-#{hotel.id}") |> render_click()

    assert has_element?(view, "#stay-booking-form")

    view
    |> form("#stay-booking-form", %{
      "check_in" => Date.to_iso8601(check_in),
      "check_out" => Date.to_iso8601(Date.add(check_in, 2)),
      "rooms" => "1",
      "guests" => "2"
    })
    |> render_submit()

    assert_redirect(view, "/dashboard?tab=chyllz")

    assert [booking] = HotelBookings.list_for_user(user.id)
    assert booking.hotel_name == "Diani Sands Test"
    assert booking.nights == 2
  end

  test "guests are asked to sign in before reserving", %{conn: conn} do
    hotel = hotel_fixture(%{name: "Guest Hotel Test"})

    {:ok, view, _html} = live(conn, ~p"/tour-packages/hotels")
    view |> element("#hotel-card-#{hotel.id}") |> render_click()

    assert has_element?(view, "#stay-booking-login")
    refute has_element?(view, "#stay-booking-form")
  end
end
