defmodule Xpressbus.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Xpressbus.Repo

  alias Xpressbus.Accounts.{LoginCode, User, Subscriber, Transaction}
  alias Xpressbus.LoginEmail

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
      |> User.registration_changeset(Map.put(attrs, "referral_code", generate_referral_code()))
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

  @doc """
  Fetches a user by primary key. For backwards compatibility, a phone number is
  also accepted (legacy sessions and registrations store the phone number).
  """
  def get_user(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _uuid} -> Repo.get(User, id)
      :error -> get_user_by_phone(id)
    end
  end

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

  # --- Email OTP login ------------------------------------------------------

  @login_code_ttl_seconds 10 * 60
  @login_code_resend_seconds 60
  @login_code_max_attempts 5
  @login_code_max_per_hour 5

  @doc "How long a login code stays valid, in minutes."
  def login_code_ttl_minutes, do: div(@login_code_ttl_seconds, 60)

  @doc "Minimum number of seconds between login-code emails for one account."
  def login_code_resend_seconds, do: @login_code_resend_seconds

  @doc """
  Gets a single user by email (case-insensitive).
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email |> String.trim() |> String.downcase())
  end

  @doc """
  Finds the account for a login identifier, which may be a phone number or an
  email address.
  """
  def find_user_for_login(identifier) when is_binary(identifier) do
    identifier = String.trim(identifier)

    if String.contains?(identifier, "@") do
      get_user_by_email(identifier)
    else
      get_user_by_phone(identifier) || get_user_by_phone(digits_only(identifier))
    end
  end

  @doc """
  Starts an email-OTP login for `identifier` (phone or email) by emailing a
  single-use 6-digit code.

  Returns `{:ok, user}` when the email was handed to the mailer, or one of
  `{:error, :not_found}`, `{:error, :missing_email}`,
  `{:error, :delivery_failed}`, `{:error, {:cooldown, user}}` and
  `{:error, {:rate_limited, user}}`.
  """
  def request_login_code(identifier) when is_binary(identifier) do
    case find_user_for_login(identifier) do
      nil -> {:error, :not_found}
      %User{} = user -> send_login_code(user)
    end
  end

  @doc """
  Re-sends a login code for an account that already started the login flow.
  """
  def resend_login_code(user_id) do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      %User{} = user -> send_login_code(user)
    end
  end

  @doc """
  Verifies a 6-digit login code for `user_id`. On success the code is consumed
  and the user is returned.
  """
  def verify_login_code(user_id, code) when is_binary(user_id) and is_binary(code) do
    code = String.trim(code)
    now = now()

    query =
      from(lc in LoginCode,
        where: lc.user_id == ^user_id and is_nil(lc.consumed_at),
        order_by: [desc: lc.inserted_at],
        limit: 1
      )

    case Repo.one(query) do
      nil ->
        {:error, :no_code}

      %LoginCode{} = login_code ->
        cond do
          DateTime.compare(login_code.expires_at, now) != :gt ->
            {:error, :expired}

          login_code.attempts >= @login_code_max_attempts ->
            {:error, :too_many_attempts}

          secure_compare(digest_login_code(user_id, code), login_code.code_digest) ->
            consume_login_code(login_code, now)

          true ->
            login_code
            |> LoginCode.changeset(%{attempts: login_code.attempts + 1})
            |> Repo.update()

            {:error, :invalid}
        end
    end
  end

  def verify_login_code(_user_id, _code), do: {:error, :invalid}

  defp consume_login_code(login_code, now) do
    with {:ok, _login_code} <-
           login_code
           |> LoginCode.changeset(%{consumed_at: now})
           |> Repo.update(),
         %User{} = user <- get_user(login_code.user_id) do
      {:ok, user}
    else
      _ -> {:error, :not_found}
    end
  end

  defp send_login_code(%User{email: email} = user)
       when is_binary(email) and email != "" do
    now = now()
    cooldown_cutoff = DateTime.add(now, -@login_code_resend_seconds, :second)
    hour_cutoff = DateTime.add(now, -3600, :second)

    last_code =
      Repo.one(
        from(lc in LoginCode,
          where: lc.user_id == ^user.id,
          order_by: [desc: lc.inserted_at],
          limit: 1
        )
      )

    recent_count =
      Repo.aggregate(
        from(lc in LoginCode,
          where: lc.user_id == ^user.id and lc.inserted_at >= ^hour_cutoff
        ),
        :count,
        :id
      )

    cond do
      last_code && DateTime.compare(last_code.inserted_at, cooldown_cutoff) == :gt ->
        {:error, {:cooldown, user}}

      recent_count >= @login_code_max_per_hour ->
        {:error, {:rate_limited, user}}

      true ->
        code = generate_login_code()

        with {:ok, _login_code} <- store_login_code(user, code, now),
             :ok <- LoginEmail.deliver(user, code, login_code_ttl_minutes()) do
          {:ok, user}
        else
          {:error, _reason} -> {:error, :delivery_failed}
        end
    end
  end

  defp send_login_code(%User{}), do: {:error, :missing_email}

  defp store_login_code(%User{} = user, code, now) do
    Repo.transaction(fn ->
      # Invalidate any previous unconsumed codes for this account.
      Repo.update_all(
        from(lc in LoginCode, where: lc.user_id == ^user.id and is_nil(lc.consumed_at)),
        set: [consumed_at: now]
      )

      # Housekeeping: drop codes older than a day.
      Repo.delete_all(
        from(lc in LoginCode,
          where: lc.user_id == ^user.id and lc.inserted_at < ^DateTime.add(now, -86_400, :second)
        )
      )

      %LoginCode{}
      |> LoginCode.changeset(%{
        user_id: user.id,
        code_digest: digest_login_code(user.id, code),
        expires_at: DateTime.add(now, @login_code_ttl_seconds, :second)
      })
      |> Repo.insert()
    end)
  end

  defp generate_login_code do
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp digest_login_code(user_id, code) do
    :crypto.mac(:hmac, :sha256, login_code_secret(), "#{user_id}:#{code}")
    |> Base.encode16(case: :lower)
  end

  # The digest is keyed with the application's secret key base, so a leaked
  # database alone is not enough to brute-force 6-digit codes offline.
  defp login_code_secret do
    endpoint_config = Application.get_env(:xpressbus, XpressbusWeb.Endpoint, [])

    Keyword.get(endpoint_config, :secret_key_base) ||
      Application.get_env(:xpressbus, :login_code_secret) ||
      "komiuta-login-code-dev-secret"
  end

  defp secure_compare(left, right) when is_binary(left) and is_binary(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp digits_only(value), do: String.replace(value, ~r/[^0-9]/, "")

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
