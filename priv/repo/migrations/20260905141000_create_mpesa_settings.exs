defmodule Xpressbus.Repo.Migrations.CreateMpesaSettings do
  use Ecto.Migration

  def change do
    create table(:mpesa_settings, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:mode, :string, default: "sandbox")
      add(:consumer_key, :string)
      add(:consumer_secret, :string)
      add(:business_shortcode, :string)
      add(:passkey, :string)
      add(:callback_url, :string)
      add(:confirmation_url, :string)
      add(:validation_url, :string)
      add(:account_reference, :string)
      add(:transaction_desc, :string, default: "Bus Ticket Payment")

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:mpesa_settings, [:mode]))
  end
end
