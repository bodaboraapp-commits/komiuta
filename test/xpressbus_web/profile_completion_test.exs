defmodule Xpressbus.ProfileCompletionTest do
  use XpressbusWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Xpressbus.Accounts
  alias Xpressbus.Accounts.User

  defp unique, do: System.unique_integer([:positive])

  defp phone do
    "0712" <> (unique() |> rem(10_000_000) |> Integer.to_string() |> String.pad_leading(7, "0"))
  end

  defp email(prefix \\ "user"), do: "#{prefix}#{unique()}@example.com"

  defp valid_user(overrides \\ %{}) do
    Map.merge(%User{name: "Test User", phone: phone(), email: email()}, overrides)
  end

  describe "profile_complete?/1" do
    test "requires both a real email and a real phone" do
      user = valid_user()
      assert Accounts.profile_complete?(user)

      refute Accounts.profile_complete?(%{user | phone: nil})
      refute Accounts.profile_complete?(%{user | phone: "G-abcdefgh"})
      refute Accounts.profile_complete?(%{user | phone: ""})
      refute Accounts.profile_complete?(%{user | email: nil})
      refute Accounts.profile_complete?(%{user | email: ""})
      refute Accounts.profile_complete?(%{user | email: "0712345678@xpressbus.com"})
      refute Accounts.profile_complete?(nil)
    end
  end

  describe "Google signup" do
    test "creates an email-only account, then requires a phone before completion" do
      google_email = email("google")

      assert {:ok, user} =
               Accounts.find_or_create_google_user(%{name: "Google User", email: google_email})

      assert user.email == google_email
      assert is_nil(user.phone)
      refute Accounts.profile_complete?(user)

      assert {:ok, completed} = Accounts.complete_profile(user, %{phone: "0712 345 678"})
      assert completed.phone == "0712345678"
      assert Accounts.profile_complete?(completed)
    end

    test "returns the existing account for a known Google email" do
      existing = valid_user()

      {:ok, existing} =
        Accounts.create_user(%{name: existing.name, phone: existing.phone, email: existing.email})

      assert {:ok, found} =
               Accounts.find_or_create_google_user(%{name: "Other", email: existing.email})

      assert found.id == existing.id
    end
  end

  describe "registration" do
    test "requires both phone and email" do
      assert {:error, changeset} =
               Accounts.register_user(%{
                 "name" => "No Phone",
                 "email" => email("nophone")
               })

      assert changeset.errors[:phone]

      assert {:error, changeset} =
               Accounts.register_user(%{
                 "name" => "No Email",
                 "phone" => phone()
               })

      assert changeset.errors[:email]
    end

    test "creates a complete account when both are provided" do
      assert {:ok, user} =
               Accounts.register_user(%{
                 "name" => "Complete User",
                 "phone" => phone(),
                 "email" => email("complete")
               })

      assert Accounts.profile_complete?(user)
    end
  end

  describe "complete-profile enforcement" do
    test "an incomplete user is sent to /user/complete-profile instead of the dashboard" do
      {:ok, user} =
        Accounts.find_or_create_google_user(%{name: "Incomplete", email: email("incomplete")})

      conn = build_conn() |> Plug.Test.init_test_session(%{user_id: user.id})

      assert {:error, {:redirect, %{to: "/user/complete-profile"}}} = live(conn, ~p"/dashboard")
    end

    test "the complete-profile page renders for an incomplete signed-in user" do
      {:ok, user} =
        Accounts.find_or_create_google_user(%{
          name: "Incomplete Page",
          email: email("profilepage")
        })

      conn =
        build_conn()
        |> Plug.Test.init_test_session(%{user_id: user.id})
        |> get(~p"/user/complete-profile")

      assert html_response(conn, 200) =~ "Complete your profile"
      assert html_response(conn, 200) =~ "Phone number"
    end

    test "guests are redirected to login" do
      conn = get(build_conn(), ~p"/user/complete-profile")
      assert redirected_to(conn) == ~p"/user/login"
    end
  end
end
