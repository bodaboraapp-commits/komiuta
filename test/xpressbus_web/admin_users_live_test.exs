defmodule XpressbusWeb.AdminUsersLiveTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  defp admin_conn(conn) do
    Plug.Test.init_test_session(conn, %{admin_id: 1})
  end

  test "redirects non-admin users to the admin login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, ~p"/admin/users")
  end

  test "lists users, shows ticket counts and filters by search", %{conn: conn} do
    alice =
      user_fixture(%{name: "Alice Example", phone: "0712300001", email: "alice@example.com"})

    user_fixture(%{name: "Bob Example", phone: "0712300002", email: "bob@example.com"})

    Repo.insert!(%Ticket{
      ticket_id: "TKT-ADMIN1",
      from: "Mombasa",
      to: "Nairobi",
      travel_date: ~D[2026-10-30],
      departure: "7:00 AM",
      arrival: "5:30 PM",
      company: "MashPoa",
      price: "KSH 2300",
      seats: "[\"6\"]",
      passenger_name: alice.name,
      passenger_phone: alice.phone,
      payment_method: "mpesa",
      status: "confirmed",
      type: "One Way"
    })

    {:ok, view, html} = live(admin_conn(conn), ~p"/admin/users")

    assert html =~ "User/Agent List"
    assert html =~ "Alice Example"
    assert html =~ "Bob Example"
    assert html =~ "KES 120.5"

    filtered =
      view
      |> form("#user-search-form", %{"search" => "alice"})
      |> render_change()

    assert filtered =~ "Alice Example"
    refute filtered =~ "Bob Example"
  end

  test "paginates the user list", %{conn: conn} do
    for index <- 1..16 do
      suffix = index |> Integer.to_string() |> String.pad_leading(5, "0")

      user_fixture(%{
        name: "Paged User #{index}",
        phone: "07123" <> suffix,
        email: "paged#{index}@example.com"
      })
    end

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/users")
    assert render(view) =~ "of 16 entries"

    second_page = render_click(view, "change_page", %{"page" => "2"})
    assert second_page =~ "Showing 16 to 16 of 16 entries"
    assert second_page =~ "Paged User"
  end

  test "empty search state is shown when nothing matches", %{conn: conn} do
    user_fixture(%{name: "Solo User", phone: "0712300009", email: "solo@example.com"})

    {:ok, view, _html} = live(admin_conn(conn), ~p"/admin/users")

    empty =
      view
      |> form("#user-search-form", %{"search" => "no-such-user"})
      |> render_change()

    assert empty =~ "No users found"
  end
end
