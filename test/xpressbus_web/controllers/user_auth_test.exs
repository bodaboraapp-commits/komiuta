defmodule XpressbusWeb.UserAuthTest do
  use XpressbusWeb.ConnCase

  import Ecto.Query
  import Swoosh.TestAssertions

  alias Xpressbus.{Accounts, Repo}
  alias Xpressbus.Accounts.{LoginCode, User}

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        "name" => "Auth Tester",
        "phone" => "07" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
        "email" => "auth#{unique}@example.com"
      })

    user
  end

  defp code_from_email do
    {:email, email} = assert_email_sent()

    [_, code] = Regex.run(~r/\b(\d{6})\b/, email.text_body)
    code
  end

  defp latest_login_code(%User{} = user) do
    Repo.one(
      from(lc in LoginCode,
        where: lc.user_id == ^user.id,
        order_by: [desc: lc.inserted_at],
        limit: 1
      )
    )
  end

  test "login page asks for phone", %{conn: conn} do
    conn = get(conn, ~p"/user/login")

    assert html_response(conn, 200) =~ "Phone"
    assert html_response(conn, 200) =~ "07XX XXX XXX"
    assert html_response(conn, 200) =~ "Send Login Code"
  end

  test "requesting a code emails it and redirects to verification", %{conn: conn} do
    user = create_user()

    conn = post(conn, ~p"/user/auth", %{"user" => %{"identifier" => user.phone}})

    assert redirected_to(conn) == "/user/verify"
    assert get_session(conn, :login_user_id) == user.id
    assert get_session(conn, :login_identifier) =~ "@example.com"
    assert_email_sent()
  end

  test "an unknown identifier redirects to sign-up", %{conn: conn} do
    conn = post(conn, ~p"/user/auth", %{"user" => %{"identifier" => "nobody@example.com"}})

    assert redirected_to(conn) == "/user/signup"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "No account found"
  end

  test "verify page requires a pending login", %{conn: conn} do
    conn = get(conn, ~p"/user/verify")

    assert redirected_to(conn) == "/user/login"
  end

  test "a wrong code does not start a session", %{conn: conn} do
    user = create_user()
    conn = post(conn, ~p"/user/auth", %{"user" => %{"identifier" => user.phone}})
    code = code_from_email()
    wrong = if code == "000000", do: "111111", else: "000000"

    conn = post(recycle(conn), ~p"/user/verify", %{"user" => %{"code" => wrong}})

    assert redirected_to(conn) == "/user/verify"
    refute get_session(conn, :user_id)
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not correct"
  end

  test "the correct code logs the user in", %{conn: conn} do
    user = create_user()
    conn = post(conn, ~p"/user/auth", %{"user" => %{"identifier" => user.phone}})
    code = code_from_email()

    conn = post(recycle(conn), ~p"/user/verify", %{"user" => %{"code" => code}})

    assert redirected_to(conn) == "/dashboard"
    assert get_session(conn, :user_id) == user.id
    refute get_session(conn, :login_user_id)
    refute latest_login_code(user).consumed_at == nil
  end

  test "resend is rate limited by the cooldown", %{conn: conn} do
    user = create_user()
    conn = post(conn, ~p"/user/auth", %{"user" => %{"identifier" => user.phone}})

    conn = post(recycle(conn), ~p"/user/verify/resend", %{})

    assert redirected_to(conn) == "/user/verify"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "just sent"
  end

  test "registration requires a valid email", %{conn: conn} do
    unique = System.unique_integer([:positive])

    conn =
      post(conn, ~p"/user/register", %{
        "user" => %{
          "name" => "No Email",
          "phone" => "04" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
          "email" => ""
        }
      })

    assert html_response(conn, 200) =~ "valid email"
    assert Repo.aggregate(User, :count, :id) == 0
  end

  test "registration creates the account and starts a session", %{conn: conn} do
    unique = System.unique_integer([:positive])
    email = "new#{unique}@example.com"

    conn =
      post(conn, ~p"/user/register", %{
        "user" => %{
          "name" => "New Traveller",
          "phone" => "03" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
          "email" => String.upcase(email)
        }
      })

    assert redirected_to(conn) == "/dashboard"
    assert get_session(conn, :user_id)

    user = Accounts.get_user_by_email(email)
    assert user
    assert user.email == email
  end
end
