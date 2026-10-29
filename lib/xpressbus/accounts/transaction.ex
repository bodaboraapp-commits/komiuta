defmodule Xpressbus.Accounts.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    field(:amount, :decimal)
    field(:type, :string)
    field(:status, :string)
    field(:description, :string)
    field(:reference_id, :string)

    belongs_to(:user, Xpressbus.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:amount, :type, :status, :description, :reference_id, :user_id])
    |> validate_required([:amount, :type, :status, :user_id])
  end
end
