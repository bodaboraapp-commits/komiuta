defmodule Xpressbus.AccountsTest do
  use Xpressbus.DataCase

  alias Xpressbus.Accounts

  describe "users" do
    alias Xpressbus.Accounts.User

    import Xpressbus.AccountsFixtures

    @invalid_attrs %{
      name: nil,
      phone: nil,
      email: nil,
      wallet_balance: nil,
      avatar_url: nil,
      default_payment_method: nil
    }

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Accounts.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Accounts.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{
        name: "some name",
        phone: "0712345678",
        email: "valid.user@example.com",
        wallet_balance: "120.5",
        avatar_url: "some avatar_url",
        default_payment_method: "some default_payment_method"
      }

      assert {:ok, %User{} = user} = Accounts.create_user(valid_attrs)
      assert user.name == "some name"
      assert user.phone == "0712345678"
      assert user.email == "valid.user@example.com"
      assert user.wallet_balance == Decimal.new("120.5")
      assert user.avatar_url == "some avatar_url"
      assert user.default_payment_method == "some default_payment_method"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()

      update_attrs = %{
        name: "some updated name",
        phone: "0723456789",
        email: "updated.user@example.com",
        wallet_balance: "456.7",
        avatar_url: "some updated avatar_url",
        default_payment_method: "some updated default_payment_method"
      }

      assert {:ok, %User{} = user} = Accounts.update_user(user, update_attrs)
      assert user.name == "some updated name"
      assert user.phone == "0723456789"
      assert user.email == "updated.user@example.com"
      assert user.wallet_balance == Decimal.new("456.7")
      assert user.avatar_url == "some updated avatar_url"
      assert user.default_payment_method == "some updated default_payment_method"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert user == Accounts.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end
end
