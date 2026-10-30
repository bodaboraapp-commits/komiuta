defmodule XpressbusWeb.EmailChangeDashboardTest do
  use XpressbusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Xpressbus.AccountsFixtures

  alias Xpressbus.Accounts

  defp signed_in(conn, user) do
    Plug.Test.init_test_session(conn, %{user_id: user.id})
  end

  test "the profile form cannot change the account email directly", %{conn: conn} do
    user = user_fixture()

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard")

    render_submit(view, "update_profile", %{
      "user" => %{"name" => "Updated Name", "email" => "attacker@example.com"}
    })

    updated = Accounts.get_user!(user.id)
    assert updated.name == "Updated Name"
    assert updated.email == user.email
  end

  test "changing email starts the verification-code flow", %{conn: conn} do
    user = user_fixture()
    new_email = "dashboard-#{System.unique_integer([:positive])}@example.com"

    {:ok, view, _html} = live(signed_in(conn, user), ~p"/dashboard")

    html = render_click(view, "open_email_change")
    assert html =~ "Change email"
    assert html =~ "verification code"

    html =
      view
      |> form("#email-change-request-form", %{"email_change" => %{"new_email" => new_email}})
      |> render_submit()

    assert html =~ "Verification Code"
    assert html =~ new_email

    # A wrong code is rejected without changing the account.
    html = render_submit(view, "confirm_email_change", %{"code" => "000000"})
    assert html =~ "not correct"
    assert Accounts.get_user!(user.id).email == user.email
  end
end
