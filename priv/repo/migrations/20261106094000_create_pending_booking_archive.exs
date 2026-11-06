defmodule Xpressbus.Repo.Migrations.CreatePendingBookingArchive do
  @moduledoc """
  Storage for rows removed by the stale-pending-booking cleanup.

  Every cleanup archives the affected ticket/payment rows as JSON before
  deleting them, so data can be recovered without a full database restore.
  """

  use Ecto.Migration

  def change do
    create table(:pending_booking_archive) do
      add :kind, :string, null: false
      add :ticket_id, :string
      add :reference, :string
      add :payload, :json
      add :archived_at, :utc_datetime, null: false
    end

    create index(:pending_booking_archive, [:ticket_id])
    create index(:pending_booking_archive, [:archived_at])
  end
end
