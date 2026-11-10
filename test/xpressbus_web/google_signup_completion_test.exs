defmodule XpressbusWeb.GoogleSignupCompletionTest do
  use XpressbusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Xpressbus.Accounts
  alias XpressbusWeb.AuthController

  defp unique, do: System.unique_integer([:positive])

  defp email(prefix), do: "#{prefix}#{unique()}@gmail.com"

  defp phone do
    "0722" <> (unique() |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0"))
  end

  defp google_auth(email, name) do
    %Ueberauth.Auth{
      uid: "google-#{email}",
      provider: :google,
      info: %Ueberauth.Auth.Info{email: email, name: name}
    }
  end

  defp google_callback(conn, email, name) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.Controller.fetch_flash()
    |> Plug.Conn.assign(:ueberauth_auth, google_auth(email, name))
    |> AuthController.callback(%{})
  end

  describe "Google OAuth signup completion" do
    test "a new Google account is routed to the Details step, not the dashboard", %{conn: conn} do
      google_email = email("newgmail")

      conn = google_callback(conn, google_email, "Gmail Traveller")
      session = get_session(conn)

      assert redirected_to(conn) == "/user/complete-profile"
      assert user_id = session["user_id"]
      assert %{email: ^google_email} = Accounts.get_user(user_id)

      session_conn = build_conn() |> Plug.Test.init_test_session(session)

      assert {:error, {:redirect, %{to: "/user/complete-profile"}}} =
               live(session_conn, ~p"/dashboard")

      page = session_conn |> get(~p"/user/complete-profile") |> html_response(200)
      assert page =~ google_email
      assert page =~ "Phone number"
      refute page =~ ~s(id="complete-email")
    end

    test "a returning Google account with no phone is still sent to Details", %{conn: conn} do
      google_email = email("incomplete")

      {:ok, user} =
        Accounts.find_or_create_google_user(%{name: "Incomplete Gmail", email: google_email})

      refute Accounts.profile_complete?(user)

      conn = google_callback(conn, google_email, "Incomplete Gmail")

      assert redirected_to(conn) == "/user/complete-profile"
      assert get_session(conn, :user_id) == user.id
    end

    test "completing Details unlocks the dashboard instead of looping", %{conn: conn} do
      google_email = email("finish")

      conn = google_callback(conn, google_email, "Finish Gmail")
      session_conn = build_conn() |> Plug.Test.init_test_session(get_session(conn))

      completed =
        post(session_conn, ~p"/user/complete-profile", %{
          "user" => %{"phone" => phone()}
        })

      assert redirected_to(completed) == "/dashboard"

      completed_user = Accounts.get_user_by_email(google_email)
      assert Accounts.profile_complete?(completed_user)

      dashboard_conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: completed_user.id})

      dashboard = dashboard_conn |> get(~p"/dashboard") |> html_response(200)
      assert dashboard =~ "Welcome back"
      assert dashboard =~ "My Bus"
    end

    test "a returning complete Google account goes straight to the dashboard", %{conn: conn} do
      complete_email = email("complete")
      complete_phone = phone()

      {:ok, _user} =
        Accounts.create_user(%{
          name: "Complete Gmail",
          email: complete_email,
          phone: complete_phone
        })

      conn = google_callback(conn, complete_email, "Complete Gmail")

      assert redirected_to(conn) == "/dashboard"
    end

    test "a signed-in incomplete Gmail user cannot start signup again", %{conn: conn} do
      google_email = email("signupguard")

      {:ok, user} =
        Accounts.find_or_create_google_user(%{name: "Signup Guard", email: google_email})

      conn =
        conn
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> get(~p"/user/signup")

      assert redirected_to(conn) == "/user/complete-profile"
    end
  end
end
