defmodule Xpressbus.Repo.Migrations.CreateBanners do
  use Ecto.Migration

  def change do
    create table(:banners, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :image, :string
      add :status, :string
      add :color, :string

      timestamps(type: :utc_datetime)
    end
  end
end
