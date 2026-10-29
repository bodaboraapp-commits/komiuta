defmodule Xpressbus.Repo.Migrations.CreateInsuranceTables do
  @moduledoc """
  Creates the database-backed InSURE catalogue.

  The public insurance page used to render hard-coded plans, coverage rows and
  FAQs. Those now live in `insurance_plans` and `insurance_faqs`. The default
  launch content is inserted by this migration (via
  `Xpressbus.Insurance.ensure_defaults/0`) so a deploy that only runs
  `mix ecto.migrate` never serves an empty insurance page.
  """

  use Ecto.Migration

  def up do
    create table(:insurance_plans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :price, :decimal, null: false, precision: 12, scale: 2
      add :period, :string, null: false
      add :tagline, :string
      add :features, :json
      add :coverage, :json
      add :popular, :boolean, null: false, default: false
      add :active, :boolean, null: false, default: true
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:insurance_plans, [:name])

    create table(:insurance_faqs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :question, :string, null: false
      add :answer, :text, null: false
      add :position, :integer, null: false, default: 0
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:insurance_faqs, [:question])

    flush()

    Xpressbus.Insurance.ensure_defaults()
  end

  def down do
    drop table(:insurance_faqs)
    drop table(:insurance_plans)
  end
end
