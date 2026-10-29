defmodule Xpressbus.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Xpressbus.Accounts` context.
  """

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "some email#{System.unique_integer([:positive])}"

  @doc """
  Generate a unique user phone.
  """
  def unique_user_phone, do: "some phone#{System.unique_integer([:positive])}"

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        avatar_url: "some avatar_url",
        default_payment_method: "some default_payment_method",
        email: unique_user_email(),
        name: "some name",
        phone: unique_user_phone(),
        wallet_balance: "120.5"
      })
      |> Xpressbus.Accounts.create_user()

    user
  end
end
