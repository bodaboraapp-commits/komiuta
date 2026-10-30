defmodule Xpressbus.Accounts.EmailChangeCode do
  @moduledoc """
  A single-use, time-limited code that verifies ownership of a *new* email
  address before it replaces the account's current email.

  Only a keyed digest is stored; the plaintext code is emailed to the new
  address.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_change_codes" do
    field(:new_email, :string)
    field(:code_digest, :string)
    field(:expires_at, :utc_datetime)
    field(:attempts, :integer, default: 0)
    field(:consumed_at, :utc_datetime)

    belongs_to(:user, Xpressbus.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  def changeset(email_change_code, attrs) do
    email_change_code
    |> cast(attrs, [:user_id, :new_email, :code_digest, :expires_at, :attempts, :consumed_at])
    |> validate_required([:user_id, :new_email, :code_digest, :expires_at])
  end
end
