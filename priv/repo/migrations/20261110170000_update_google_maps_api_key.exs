defmodule Xpressbus.Repo.Migrations.UpdateGoogleMapsApiKey do
  use Ecto.Migration
  import Ecto.Query

  alias Xpressbus.Integrations.PaymentConfig
  alias Xpressbus.Repo

  @api_key "AIzaSyCYpkGBnoJPhcm7APl5nm-xwXcxdosATgk"

  def up do
    case Repo.get_by(PaymentConfig, provider: "google_maps") do
      nil ->
        %PaymentConfig{}
        |> PaymentConfig.changeset(%{
          provider: "google_maps",
          active: true,
          config: %{"api_key" => @api_key}
        })
        |> Repo.insert!()

      config ->
        config
        |> PaymentConfig.changeset(%{
          active: true,
          config: Map.put(config.config || %{}, "api_key", @api_key)
        })
        |> Repo.update!()
    end
  end

  def down do
    # The key is an operator credential; do not restore a previous key on rollback.
    :ok
  end
end
