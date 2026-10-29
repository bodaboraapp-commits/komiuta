defmodule Xpressbus.LoginCodeTest do
  use Xpressbus.DataCase

  import Ecto.Query
  import Swoosh.TestAssertions

  alias Xpressbus.{Accounts, Repo}
  alias Xpressbus.Accounts.{LoginCode, User}

  defp create_user(overrides \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Map.merge(
        %{
          "name" => "OTP Tester",
          "phone" => "07" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
          "email" => "otp#{unique}@example.com"
        },
        overrides
      )

    {:ok, user} = Accounts.register_user(attrs)
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

  describe "request_login_code/1" do
    test "emails a six-digit code when the phone number matches an account" do
      user = create_user()

      assert {:ok, %User{id: user_id}} = Accounts.request_login_code(user.phone)
      assert user_id == user.id

      {:email, email} = assert_email_sent()

      assert Enum.any?(email.to, fn {_name, address} -> address == user.email end)
      assert email.subject =~ "login code"
      assert Regex.match?(~r/\b\d{6}\b/, email.text_body)

      code = latest_login_code(user)
      assert code
      refute code.consumed_at
      assert DateTime.compare(code.expires_at, DateTime.utc_now()) == :gt
    end

    test "accepts an email address as the identifier" do
      user = create_user()

      assert {:ok, %User{id: user_id}} = Accounts.request_login_code(user.email)
      assert user_id == user.id
      assert_email_sent()
    end

    test "returns not_found for an unknown account" do
      assert {:error, :not_found} = Accounts.request_login_code("nobody@example.com")
    end

    test "returns missing_email when the account has no email address" do
      unique = System.unique_integer([:positive])

      {:ok, user} =
        Accounts.create_user(%{
          name: "No Email",
          phone: "08" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0"))
        })

      assert {:error, :missing_email} = Accounts.request_login_code(user.phone)
      assert_no_email_sent()
    end

    test "rate limits repeated requests with a cooldown" do
      user = create_user()
      assert {:ok, _user} = Accounts.request_login_code(user.phone)
      assert {:error, {:cooldown, %User{id: user_id}}} = Accounts.request_login_code(user.phone)
      assert user_id == user.id
    end
  end

  describe "verify_login_code/2" do
    test "accepts the correct code once" do
      user = create_user()
      assert {:ok, _user} = Accounts.request_login_code(user.phone)
      code = code_from_email()

      assert {:ok, %User{id: user_id}} = Accounts.verify_login_code(user.id, code)
      assert user_id == user.id

      # The code is single-use.
      assert {:error, :no_code} = Accounts.verify_login_code(user.id, code)
    end

    test "rejects a wrong code and counts the attempt" do
      user = create_user()
      assert {:ok, _user} = Accounts.request_login_code(user.phone)
      code = code_from_email()
      wrong = if code == "000000", do: "111111", else: "000000"

      assert {:error, :invalid} = Accounts.verify_login_code(user.id, wrong)
      assert latest_login_code(user).attempts == 1
    end

    test "locks out after too many attempts" do
      user = create_user()
      assert {:ok, _user} = Accounts.request_login_code(user.phone)
      code = code_from_email()
      wrong = if code == "000000", do: "111111", else: "000000"

      for _ <- 1..5 do
        assert {:error, :invalid} = Accounts.verify_login_code(user.id, wrong)
      end

      assert {:error, :too_many_attempts} = Accounts.verify_login_code(user.id, code)
    end

    test "rejects expired codes" do
      user = create_user()
      assert {:ok, _user} = Accounts.request_login_code(user.phone)
      code = code_from_email()

      login_code = latest_login_code(user)

      login_code
      |> Ecto.Changeset.change(
        expires_at: DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      assert {:error, :expired} = Accounts.verify_login_code(user.id, code)
    end
  end

  describe "resend_login_code/1" do
    test "is rate limited by the cooldown" do
      user = create_user()
      assert {:ok, _user} = Accounts.request_login_code(user.phone)
      assert {:error, {:cooldown, _user}} = Accounts.resend_login_code(user.id)
    end
  end

  describe "registration" do
    test "requires an email address" do
      unique = System.unique_integer([:positive])

      assert {:error, changeset} =
               Accounts.register_user(%{
                 "name" => "No Email",
                 "phone" => "09" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
                 "email" => ""
               })

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an invalid email address" do
      unique = System.unique_integer([:positive])

      assert {:error, changeset} =
               Accounts.register_user(%{
                 "name" => "Bad Email",
                 "phone" => "06" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
                 "email" => "not-an-email"
               })

      assert %{email: ["must be a valid email address"]} = errors_on(changeset)
    end

    test "normalises the email address to lowercase" do
      unique = System.unique_integer([:positive])

      {:ok, user} =
        Accounts.register_user(%{
          "name" => "Mixed Case",
          "phone" => "05" <> (unique |> Integer.to_string() |> String.pad_leading(8, "0")),
          "email" => "Mixed.Case#{unique}@Example.COM"
        })

      assert user.email == "mixed.case#{unique}@example.com"
    end
  end

  describe "get_user/1" do
    test "resolves UUIDs and legacy phone identifiers" do
      user = create_user()

      assert Accounts.get_user(user.id).id == user.id
      assert Accounts.get_user(user.phone).id == user.id
    end
  end
end
