defmodule Xpressbus.Integrations do
  @moduledoc """
  The Integrations context.
  """

  import Ecto.Query, warn: false
  alias Xpressbus.Repo
  alias Xpressbus.Integrations.PaymentConfig

  @doc """
  Gets the M-PESA configuration.
  """
  def get_mpesa_config do
    Repo.get_by(PaymentConfig, provider: "mpesa")
  end

  @doc """
  Upserts the M-PESA configuration.
  """
  def upsert_mpesa_config(attrs) do
    case get_mpesa_config() do
      nil ->
        %PaymentConfig{}
        |> PaymentConfig.changeset(Map.put(attrs, :provider, "mpesa"))
        |> Repo.insert()

      config ->
        config
        |> PaymentConfig.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Returns the list of integrations.
  """
  def list_integrations do
    Repo.all(PaymentConfig)
  end

  @doc """
  Gets a single payment_config.
  """
  def get_payment_config!(id), do: Repo.get!(PaymentConfig, id)

  @doc """
  Gets a payment config by provider name.
  """
  def get_config_by_provider(provider) do
    Repo.get_by(PaymentConfig, provider: provider)
  end

  @doc """
  Upserts a payment config by provider.
  Expects attrs to be a map with :active and :config (the config map).
  """
  def upsert_config_by_provider(provider, attrs) do
    case get_config_by_provider(provider) do
      nil ->
        %PaymentConfig{}
        |> PaymentConfig.changeset(Map.put(attrs, :provider, provider))
        |> Repo.insert()

      existing ->
        # Merge the config map if it's passed as a map
        new_config_data = Map.get(attrs, :config, %{})
        current_config = existing.config || %{}
        merged_config = Map.merge(current_config, new_config_data)

        updated_attrs = Map.put(attrs, :config, merged_config)

        existing
        |> PaymentConfig.changeset(updated_attrs)
        |> Repo.update()
    end
  end

  def create_payment_config(attrs \\ %{}) do
    %PaymentConfig{}
    |> PaymentConfig.changeset(attrs)
    |> Repo.insert()
  end

  def update_payment_config(%PaymentConfig{} = payment_config, attrs) do
    payment_config
    |> PaymentConfig.changeset(attrs)
    |> Repo.update()
  end

  def delete_payment_config(%PaymentConfig{} = payment_config) do
    Repo.delete(payment_config)
  end

  def change_payment_config(%PaymentConfig{} = payment_config, attrs \\ %{}) do
    PaymentConfig.changeset(payment_config, attrs)
  end
end
