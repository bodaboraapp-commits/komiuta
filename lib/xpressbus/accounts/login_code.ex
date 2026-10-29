defmodule Xpressbus.Accounts.LoginCode do
  @moduledoc """
  A single-use, time-limited email login code.

  The plaintext code is only ever sent by email; the database stores a keyed
  digest (`code_digest`) so a database leak cannot be used to derive codes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "login_codes" do
    field(:code_digest, :string)
    field(:expires_at, :utc_datetime)
    field(:attempts, :integer, default: 0)
    field(:consumed_at, :utc_datetime)

    belongs_to(:user, Xpressbus.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(login_code, attrs) do
    login_code
    |> cast(attrs, [:user_id, :code_digest, :expires_at, :attempts, :consumed_at])
    |> validate_required([:user_id, :code_digest, :expires_at])
  end
end
