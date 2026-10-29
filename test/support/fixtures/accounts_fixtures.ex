defmodule Xpressbus.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Xpressbus.Accounts` context.
  """

  @doc """
  Generate a unique user email.
  """
  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  @doc """
  Generate a unique user phone.
  """
  def unique_user_phone do
    suffix =
      System.unique_integer([:positive])
      |> rem(10_000_000)
      |> Integer.to_string()
      |> String.pad_leading(7, "0")

    "0712" <> suffix
  end

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

    # Reload so callers compare against the database-normalised values
    # (decimal columns round-trip with their configured scale).
    Xpressbus.Repo.reload!(user)
  end
end
