defmodule Xpressbus.Repo.Migrations.AddTicketCancellationAndRefunds do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add :cancelled_at, :utc_datetime
      add :cancellation_reason, :text
      add :refund_amount, :integer
      add :refund_reference, :string
    end

    create table(:ticket_refunds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, :string, null: false
      add :amount, :integer, null: false
      add :reason, :text
      add :reference, :string
      add :status, :string, default: "refunded"
      add :admin_id, :integer
      add :email_sent, :boolean, default: false
      add :sms_sent, :boolean, default: false
      add :notification_details, :map
      timestamps(type: :utc_datetime)
    end

    create index(:ticket_refunds, [:ticket_id])
  end
end
