defmodule Xpressbus.Repo.Migrations.SeedGoogleMapsIntegration do
  use Ecto.Migration
  import Ecto.Query

  alias Xpressbus.Integrations.PaymentConfig
  alias Xpressbus.Repo

  @api_key "AIzaSyBj8QwnfWXeL8Yw9PDqkW7MYLt2F1G1PS4"

  def up do
    if is_nil(Repo.get_by(PaymentConfig, provider: "google_maps")) do
      %PaymentConfig{}
      |> PaymentConfig.changeset(%{
        provider: "google_maps",
        active: true,
        config: %{"api_key" => @api_key}
      })
      |> Repo.insert!()
    end
  end

  def down do
    Repo.delete_all(from(config in PaymentConfig, where: config.provider == "google_maps"))
  end
end
