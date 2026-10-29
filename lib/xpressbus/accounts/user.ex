defmodule Xpressbus.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @email_regex ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/

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

  @doc """
  Standard changeset. Both email and phone are required: every account must be
  reachable by phone and by email (one identifier alone is not enough to log in
  or receive a one-time code).
  """
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
    |> update_change(:email, &normalize_email/1)
    |> update_change(:phone, &normalize_phone/1)
    |> validate_required([:name, :phone, :email])
    |> validate_format(:email, @email_regex, message: "must be a valid email address")
    |> validate_phone_format()
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
    |> unique_constraint(:referral_code)
  end

  @doc """
  Changeset for public registration. Registration always captures both the
  phone number and the email address.
  """
  def registration_changeset(user, attrs) do
    changeset(user, attrs)
  end

  @doc """
  Changeset used for accounts created through Google sign-in/sign-up: Google
  supplies the email, so the phone is captured in the follow-up step before the
  dashboard is shown.
  """
  def google_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :avatar_url])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:name, :email])
    |> validate_format(:email, @email_regex, message: "must be a valid email address")
    |> unique_constraint(:email)
  end

  @doc """
  Changeset that completes a profile: both identifiers are mandatory and are
  normalised before saving.
  """
  def complete_profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :phone, :email])
    |> update_change(:email, &normalize_email/1)
    |> update_change(:phone, &normalize_phone/1)
    |> validate_required([:name, :phone, :email],
      message: "is required to continue"
    )
    |> validate_format(:email, @email_regex, message: "must be a valid email address")
    |> validate_phone_format()
    |> unique_constraint(:email)
    |> unique_constraint(:phone)
  end

  defp validate_phone_format(changeset) do
    case get_field(changeset, :phone) do
      nil ->
        changeset

      phone when is_binary(phone) ->
        digits = String.replace(phone, ~r/\D/, "")

        if String.starts_with?(phone, "G-") or String.length(digits) < 9 or
             String.length(digits) > 15 do
          add_error(changeset, :phone, "must be a valid phone number")
        else
          changeset
        end
    end
  end

  defp normalize_email(email) when is_binary(email) do
    email |> String.trim() |> String.downcase()
  end

  defp normalize_email(other), do: other

  defp normalize_phone(phone) when is_binary(phone) do
    phone |> String.trim() |> String.replace(~r/[\s\-().]/, "")
  end

  defp normalize_phone(other), do: other
end
