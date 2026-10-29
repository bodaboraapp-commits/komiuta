defmodule Xpressbus.IntegrationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Xpressbus.Integrations` context.
  """

  @doc """
  Generate a unique payment_config provider.
  """
  def unique_payment_config_provider, do: "some provider#{System.unique_integer([:positive])}"

  @doc """
  Generate a payment_config.
  """
  def payment_config_fixture(attrs \\ %{}) do
    {:ok, payment_config} =
      attrs
      |> Enum.into(%{
        active: true,
        config: %{},
        provider: unique_payment_config_provider()
      })
      |> Xpressbus.Integrations.create_payment_config()

    payment_config
  end
end
