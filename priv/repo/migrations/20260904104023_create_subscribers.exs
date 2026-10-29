defmodule Xpressbus.Repo.Migrations.CreateSubscribers do
  use Ecto.Migration

  def change do
    create table(:subscribers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :status, :string, default: "Active"
      add :source, :string, default: "Homepage"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscribers, [:email])
  end
end
