defmodule Xpressbus.Repo.Migrations.CreateSavedItineraries do
  use Ecto.Migration

  def change do
    create table(:saved_itineraries) do
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:title, :string, null: false)
      add(:destination, :string, null: false)
      add(:country, :string)
      add(:start_date, :date)
      add(:end_date, :date)
      add(:travel_party, :string)
      add(:budget, :string)
      add(:preferences, :text)
      add(:art, :string, null: false, default: "mountains")
      add(:latitude, :float)
      add(:longitude, :float)
      add(:source, :string)

      timestamps(type: :utc_datetime)
    end

    create(index(:saved_itineraries, [:user_id]))
    create(index(:saved_itineraries, [:user_id, :start_date]))
  end
end
