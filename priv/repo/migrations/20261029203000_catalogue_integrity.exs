defmodule Xpressbus.Repo.Migrations.CatalogueIntegrity do
  @moduledoc """
  Makes the Chyllz catalogue tables production-safe.

  The catalogue tables only ever had seed rows, but the seeder could be run
  repeatedly and created exact duplicates (for example 21 hotel rows for 3
  hotels). Duplicated cards on a public page are a visible defect, so this
  migration:

    1. adds an `active` flag so unpublished catalogue entries never leak onto
       the public pages,
    2. removes existing duplicate rows, keeping the most recently inserted one,
    3. adds unique indexes so duplicates cannot come back.
  """

  use Ecto.Migration

  def up do
    add_active_flag(:hotels)
    add_active_flag(:hidden_gems)
    add_active_flag(:car_hires)
    add_active_flag(:events)

    flush()

    deduplicate("hotels", ["name"])
    deduplicate("hidden_gems", ["title"])
    deduplicate("car_hires", ["car_name", "location"])
    deduplicate("events", ["title", "date"])

    create unique_index(:hotels, [:name])
    create unique_index(:hidden_gems, [:title])
    create unique_index(:car_hires, [:car_name, :location])
    create unique_index(:events, [:title, :date])
  end

  def down do
    drop unique_index(:events, [:title, :date])
    drop unique_index(:car_hires, [:car_name, :location])
    drop unique_index(:hidden_gems, [:title])
    drop unique_index(:hotels, [:name])

    remove_active_flag(:events)
    remove_active_flag(:car_hires)
    remove_active_flag(:hidden_gems)
    remove_active_flag(:hotels)
  end

  defp add_active_flag(table) do
    alter table(table) do
      add(:active, :boolean, null: false, default: true)
    end
  end

  defp remove_active_flag(table) do
    alter table(table) do
      remove(:active, :boolean)
    end
  end

  # Deletes every row that shares its natural key with an older row, keeping
  # exactly one (the most recently inserted) entry per key. `<=>` is MySQL's
  # NULL-safe equality so keys with a NULL column are handled too.
  defp deduplicate(table, key_columns) do
    join_conditions =
      key_columns
      |> Enum.map(fn column -> "a.`#{column}` <=> b.`#{column}`" end)
      |> Enum.join(" AND ")

    execute("""
    DELETE a FROM #{table} a
    JOIN #{table} b
      ON #{join_conditions}
     AND (a.inserted_at < b.inserted_at OR (a.inserted_at = b.inserted_at AND a.id < b.id))
    """)
  end
end
