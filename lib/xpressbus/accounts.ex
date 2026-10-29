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
  Returns true when the value is a real email address (legacy/synthetic
  placeholder addresses such as `<phone>@xpressbus.com` do not count).
  """
  def valid_email?(email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()

    email != "" and String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) and
      not String.ends_with?(email, "@xpressbus.com")
  end

  def valid_email?(_), do: false

  @doc """
  Returns true when the value looks like a real phone number (not a Google
  placeholder such as `G-abcdefgh`).
  """
  def valid_phone?(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    not String.starts_with?(phone, "G-") and String.length(digits) >= 9 and
      String.length(digits) <= 15
  end

  def valid_phone?(_), do: false

  @doc """
  A user may only reach the dashboard once both identifiers are present and
  valid: every phone has an email and every email has a phone.
  """
  def profile_complete?(%User{} = user) do
    valid_email?(user.email) and valid_phone?(user.phone)
  end

  def profile_complete?(_), do: false

  @doc "Changeset for the complete-profile (email + phone) step."
  def change_complete_profile(%User{} = user, attrs \\ %{}) do
    # Placeholder/legacy values (Google "G-" phones, synthetic @xpressbus.com
    # addresses) are not usable: show an empty field so the user supplies a real
    # one instead of re-submitting the placeholder.
    user
    |> maybe_clear_invalid(:phone)
    |> maybe_clear_invalid(:email)
    |> User.complete_profile_changeset(attrs)
  end

  defp maybe_clear_invalid(user, field) do
    value = Map.get(user, field)
    valid? = if field == :phone, do: valid_phone?(value), else: valid_email?(value)
    if valid?, do: user, else: Map.put(user, field, nil)
  end

  @doc "Saves the complete-profile step for a signed-in user."
  def complete_profile(%User{} = user, attrs) do
    user
    |> User.complete_profile_changeset(attrs)
    |> Repo.update()
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

  A new Google account starts with only the verified email; the phone number is
  collected on the complete-profile screen before the dashboard is unlocked.
  """
  def find_or_create_google_user(info) do
    name = info.name || info[:email] |> to_string() |> String.split("@") |> hd()

    case get_user_by_email(info.email) do
      nil ->
        %User{}
        |> User.google_changeset(%{name: name, email: info.email})
        |> Repo.insert()

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
      nil ->
        {:error, :not_found}

      %User{} = user ->
        # Every account must have a real email to receive a code.
        if valid_email?(user.email) do
          send_login_code(user)
        else
          {:error, :missing_email}
        end
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
