defmodule Xpressbus.Integrations.PaymentConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "integrations" do
    field(:provider, :string)
    field(:config, :map)
    field(:active, :boolean, default: false)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment_config, attrs) do
    payment_config
    |> cast(attrs, [:provider, :config, :active])
    |> validate_required([:provider, :active])
    |> unique_constraint(:provider)
  end
end
