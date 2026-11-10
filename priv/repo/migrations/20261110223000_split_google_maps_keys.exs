defmodule Xpressbus.Repo.Migrations.SplitGoogleMapsKeys do
  use Ecto.Migration

  alias Xpressbus.Integrations.PaymentConfig
  alias Xpressbus.Repo

  @provider "google_maps"

  def up do
    case Repo.get_by(PaymentConfig, provider: @provider) do
      nil ->
        :ok

      config ->
        current = config.config || %{}
        legacy = blank_to_nil(current["api_key"])

        # The legacy key has been used for server-side Places/Geocoding calls,
        # so preserve it as the server key. The browser key is a new credential
        # the operator creates with HTTP-referrer restrictions.
        browser_key = blank_to_nil(current["browser_key"])
        server_key = blank_to_nil(current["server_key"]) || legacy

        updated =
          current
          |> Map.delete("api_key")
          |> put_or_delete("browser_key", browser_key)
          |> put_or_delete("server_key", server_key)

        if updated != current do
          config
          |> PaymentConfig.changeset(%{config: updated})
          |> Repo.update!()
        end
    end
  end

  def down do
    case Repo.get_by(PaymentConfig, provider: @provider) do
      nil ->
        :ok

      config ->
        current = config.config || %{}
        server_key = blank_to_nil(current["server_key"])

        updated =
          current
          |> Map.delete("browser_key")
          |> Map.delete("server_key")
          |> put_or_delete("api_key", server_key)

        config
        |> PaymentConfig.changeset(%{config: updated})
        |> Repo.update!()
    end
  end

  defp put_or_delete(map, _key, nil), do: map
  defp put_or_delete(map, key, value), do: Map.put(map, key, value)

  defp blank_to_nil(value) do
    case to_string(value || "") |> String.trim() do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
