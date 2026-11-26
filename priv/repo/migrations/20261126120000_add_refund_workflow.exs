defmodule Xpressbus.Repo.Migrations.AddRefundWorkflow do
  use Ecto.Migration

  def change do
    alter table(:ticket_refunds) do
      add(:customer_email, :string)
      add(:amount_approved, :integer)
      add(:resolution, :string, default: "refund")
      add(:reviewed_by, :integer)
      add(:reviewed_at, :utc_datetime)
      add(:processed_at, :utc_datetime)
      add(:admin_note, :text)
      add(:credit_code, :string)
      add(:retention_offer, :string)
      add(:retention_accepted_at, :utc_datetime)
    end

    create table(:ticket_refund_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:refund_id, :binary_id, null: false)
      add(:status, :string, null: false)
      add(:actor_type, :string, null: false, default: "system")
      add(:actor_id, :string)
      add(:note, :text)
      add(:metadata, :map, default: %{})
      timestamps(type: :utc_datetime)
    end

    create(index(:ticket_refund_events, [:refund_id]))
  end
end
