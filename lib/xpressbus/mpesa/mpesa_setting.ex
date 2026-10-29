defmodule Xpressbus.Mpesa.MpesaSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "mpesa_settings" do
    field(:mode, :string)
    field(:consumer_key, :string)
    field(:consumer_secret, :string)
    field(:business_shortcode, :string)
    field(:passkey, :string)
    field(:callback_url, :string)
    field(:confirmation_url, :string)
    field(:validation_url, :string)
    field(:account_reference, :string)
    field(:transaction_desc, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(mpesa_setting, attrs) do
    mpesa_setting
    |> cast(attrs, [
      :mode,
      :consumer_key,
      :consumer_secret,
      :business_shortcode,
      :passkey,
      :callback_url,
      :confirmation_url,
      :validation_url,
      :account_reference,
      :transaction_desc
    ])
    |> validate_required([
      :mode,
      :consumer_key,
      :consumer_secret,
      :business_shortcode,
      :passkey,
      :callback_url
    ])
    |> validate_inclusion(:mode, ["sandbox", "production"])
  end
end
