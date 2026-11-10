defmodule Xpressbus.Repo.Migrations.CreateTripFinances do
  use Ecto.Migration

  def change do
    create table(:trip_budgets) do
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:ticket_id, :string)
      add(:saved_itinerary_id, references(:saved_itineraries, on_delete: :delete_all))
      add(:amount, :decimal, precision: 12, scale: 2, null: false, default: 0)

      timestamps(type: :utc_datetime)
    end

    create(
      unique_index(:trip_budgets, [:user_id, :ticket_id], name: :trip_budgets_user_ticket_index)
    )

    create(
      unique_index(:trip_budgets, [:user_id, :saved_itinerary_id],
        name: :trip_budgets_user_itinerary_index
      )
    )

    create table(:trip_expenses) do
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:ticket_id, :string)
      add(:saved_itinerary_id, references(:saved_itineraries, on_delete: :delete_all))
      add(:label, :string, null: false)
      add(:category, :string, null: false, default: "Other")
      add(:amount, :decimal, precision: 12, scale: 2, null: false, default: 0)
      add(:spent_on, :date, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:trip_expenses, [:user_id, :ticket_id]))
    create(index(:trip_expenses, [:user_id, :saved_itinerary_id]))
  end
end
