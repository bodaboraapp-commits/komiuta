defmodule Xpressbus.Admins.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  schema "admins" do
    field(:email, :string)
    field(:hashed_password, :string)
    field(:name, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email, :hashed_password, :name])
    |> validate_required([:email, :hashed_password])
    |> unique_constraint(:email)
  end
end
