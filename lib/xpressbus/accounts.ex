defmodule Xpressbus.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Xpressbus.Repo

  alias Xpressbus.Accounts.{User, Subscriber, Transaction}

  @doc """
  Gets a single user by phone.
  """
  def get_user_by_phone(phone) when is_binary(phone) do
    Repo.get_by(User, phone: phone)
  end

  @doc """
  Registers a new user, optionally processing a referral code.
  """
  def register_user(attrs) do
    referral_code = Map.get(attrs, "referral_code", "") |> String.trim() |> String.upcase()

    # Base user registration
    result =
      %User{}
      |> User.changeset(Map.put(attrs, "referral_code", generate_referral_code()))
      |> Repo.insert()

    case {result, referral_code} do
      {{:ok, user}, ""} ->
        {:ok, user}

      {{:ok, user}, code} ->
        # Find referrer
        case Repo.get_by(User, referral_code: code) do
          # Invalid code, but proceed with registration
          nil ->
            {:ok, user}

          referrer ->
            # Link referral
            update_user(user, %{referred_by_id: referrer.id})
            {:ok, user}
        end

      {other, _} ->
        other
    end
  end

  @doc """
  Ensures a user exists by phone, creating one if not found.
  Used for guest checkout and simple dashboard login.
  """
  def ensure_user_by_phone(phone, name \\ "Guest Traveler") do
    case get_user_by_phone(phone) do
      nil ->
        create_user(%{
          phone: phone,
          name: name,
          email: "#{phone}@xpressbus.com",
          wallet_balance: 0,
          referral_code: generate_referral_code()
        })

      user ->
        {:ok, user}
    end
  end

  defp generate_referral_code do
    Base.encode64(:crypto.strong_rand_bytes(6), padding: false)
    |> String.upcase()
    |> String.slice(0..7)
  end

  @doc """
  Lists transactions for a specific user.
  """
  def list_user_transactions(user_id) do
    from(t in Transaction,
      where: t.user_id == ^user_id,
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Creates a user transaction.
  """
  def create_user_transaction(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  # --- Generated & Standard functions ---

  def list_subscribers, do: Repo.all(Subscriber)

  def create_subscriber(attrs) do
    %Subscriber{}
    |> Subscriber.changeset(attrs)
    |> Repo.insert()
  end

  def list_users, do: Repo.all(User)
  def get_user!(id), do: Repo.get!(User, id)
  def get_user(id), do: Repo.get(User, id)

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user), do: Repo.delete(user)

  def change_user(%User{} = user, attrs \\ %{}), do: User.changeset(user, attrs)

  @doc """
  Finds or creates a user from Google OAuth info.
  """
  def find_or_create_google_user(info) do
    case Repo.get_by(User, email: info.email) do
      nil ->
        # Create new user
        # Note: We use a placeholder phone or ask user later. For now, email-only.
        create_user(%{
          name: info.name,
          email: info.email,
          # Temporary unique phone placeholder
          phone: "G-" <> String.slice(info.email, 0, 8),
          wallet_balance: 0,
          referral_code: generate_referral_code()
        })

      user ->
        {:ok, user}
    end
  end
end
