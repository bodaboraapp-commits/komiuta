defmodule Xpressbus.Accounts.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "subscribers" do
    field(:email, :string)
    field(:status, :string, default: "Active")
    field(:source, :string, default: "Homepage")

    timestamps(type: :utc_datetime)
  end

  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:email, :status, :source])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> unique_constraint(:email)
  end
end
