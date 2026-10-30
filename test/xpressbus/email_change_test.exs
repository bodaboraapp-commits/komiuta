defmodule Xpressbus.EmailChangeTest do
  use Xpressbus.DataCase

  import Swoosh.TestAssertions
  import Xpressbus.AccountsFixtures

  alias Xpressbus.Accounts
  alias Xpressbus.Accounts.EmailChangeCode
  alias Xpressbus.Repo

  defp code_from_email do
    {:email, email} = assert_email_sent()
    [_, code] = Regex.run(~r/\b(\d{6})\b/, email.text_body)
    code
  end

  defp latest_code(user) do
    Repo.one(
      from(c in EmailChangeCode,
        where: c.user_id == ^user.id,
        order_by: [desc: c.inserted_at],
        limit: 1
      )
    )
  end

  describe "request_email_change/2" do
    test "emails a code to the new address and a notice to the old one" do
      user = user_fixture()
      new_email = "new-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, %{new_email: ^new_email}} = Accounts.request_email_change(user, new_email)

      {:email, code_email} = assert_email_sent()

      assert Enum.any?(code_email.to, fn {_name, address} -> address == new_email end)
      assert code_email.subject =~ "Confirm your new"

      {:email, notice_email} = assert_email_sent()

      assert Enum.any?(notice_email.to, fn {_name, address} -> address == user.email end)
      assert notice_email.subject =~ "Email change requested"

      record = latest_code(user)
      assert record.new_email == new_email
      refute record.consumed_at
      assert DateTime.compare(record.expires_at, DateTime.utc_now()) == :gt
    end

    test "rejects an invalid email address" do
      user = user_fixture()
      assert {:error, :invalid_email} = Accounts.request_email_change(user, "not-an-email")
      assert_no_email_sent()
    end

    test "rejects the current email and emails already in use" do
      user = user_fixture()
      other = user_fixture()

      assert {:error, :same_email} = Accounts.request_email_change(user, user.email)
      assert {:error, :taken} = Accounts.request_email_change(user, other.email)
      assert_no_email_sent()
    end

    test "enforces a cooldown between requests" do
      user = user_fixture()
      first = "first-#{System.unique_integer([:positive])}@example.com"
      second = "second-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, _} = Accounts.request_email_change(user, first)
      assert {:error, {:cooldown, _}} = Accounts.request_email_change(user, second)
    end
  end

  describe "verify_email_change/2" do
    test "accepts the correct code once and updates the account email" do
      user = user_fixture()
      new_email = "verified-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, _} = Accounts.request_email_change(user, new_email)
      code = code_from_email()

      assert {:ok, updated} = Accounts.verify_email_change(user, code)
      assert updated.email == new_email

      assert Accounts.get_user!(user.id).email == new_email
      assert latest_code(user).consumed_at

      # Single use.
      assert {:error, :no_code} = Accounts.verify_email_change(updated, code)
    end

    test "rejects an incorrect code and counts attempts" do
      user = user_fixture()
      new_email = "wrong-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, _} = Accounts.request_email_change(user, new_email)
      code = code_from_email()
      wrong = if code == "000000", do: "111111", else: "000000"

      assert {:error, :invalid} = Accounts.verify_email_change(user, wrong)
      assert latest_code(user).attempts == 1
      assert Accounts.get_user!(user.id).email == user.email
    end

    test "rejects expired codes and gives up after too many attempts" do
      user = user_fixture()
      new_email = "expired-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, _} = Accounts.request_email_change(user, new_email)
      code = code_from_email()

      # Drain the security notice so the next code lookup reads the right email.
      assert_email_sent(fn email -> email.subject =~ "Email change requested" end)

      latest_code(user)
      |> Ecto.Changeset.change(
        expires_at: DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      assert {:error, :expired} = Accounts.verify_email_change(user, code)

      # Let the resend cooldown elapse, then start a fresh code with its own
      # attempt budget.
      latest_code(user)
      |> Ecto.Changeset.change(
        inserted_at: DateTime.add(DateTime.utc_now(), -120, :second) |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      new_email2 = "attempts-#{System.unique_integer([:positive])}@example.com"
      assert {:ok, _} = Accounts.request_email_change(user, new_email2)
      code2 = code_from_email()
      wrong = if code2 == "000000", do: "111111", else: "000000"

      for _ <- 1..5 do
        Accounts.verify_email_change(user, wrong)
      end

      assert {:error, :too_many_attempts} = Accounts.verify_email_change(user, wrong)
    end
  end
end
