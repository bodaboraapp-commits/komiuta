defmodule Xpressbus.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:name, :string)
    field(:phone, :string)
    field(:email, :string)
    field(:wallet_balance, :decimal, default: 0)
    field(:avatar_url, :string)
    field(:default_payment_method, :string, default: "mpesa")
    field(:referral_code, :string)
    field(:points_balance, :integer, default: 0)

    belongs_to(:referred_by, Xpressbus.Accounts.User)
    has_many(:transactions, Xpressbus.Accounts.Transaction)

    timestamps(type: :utc_datetime)
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :name,
      :phone,
      :email,
      :wallet_balance,
      :avatar_url,
      :default_payment_method,
      :referral_code,
      :referred_by_id,
      :points_balance
    ])
    |> validate_required([:name, :phone])
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
    |> unique_constraint(:referral_code)
  end
end
