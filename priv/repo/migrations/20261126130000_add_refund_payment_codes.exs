defmodule Xpressbus.Repo.Migrations.AddRefundPaymentCodes do
  use Ecto.Migration

  def change do
    alter table(:ticket_refunds) do
      add(:payment_id, :binary_id)
      add(:payment_confirmation_code, :string)
      add(:payment_reversal_code, :string)
    end
  end
end
