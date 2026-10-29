defmodule XpressbusWeb.UserController do
  @moduledoc """
  Phone/email login using one-time codes sent by email.

  Phone-number-only authentication allowed anyone who knew a customer's number
  to access that account. Login now always requires a 6-digit code delivered to
  the account's verified email address (Google sign-in remains available).
  """

  use XpressbusWeb, :controller

  alias Xpressbus.Accounts

  def login(conn, _params) do
    render(conn, :login)
  end

  def registration(conn, _params) do
    render(conn, :registration)
  end

  def authenticate(conn, %{"user" => user_params}) do
    identifier =
      (user_params["identifier"] || user_params["phone"] || user_params["email"] || "")
      |> to_string()
      |> String.trim()

    if identifier == "" do
      conn
      |> put_flash(:error, "Enter your phone number or email address.")
      |> render(:login)
    else
      case Accounts.request_login_code(identifier) do
        {:ok, user} ->
          conn
          |> start_verification(
            user,
            "We emailed a 6-digit login code to #{mask_email(user.email)}."
          )
          |> redirect(to: ~p"/user/verify")

        {:error, :not_found} ->
          conn
          |> put_flash(:error, "No account found with those details. Please sign up first.")
          |> redirect(to: ~p"/user/signup")

        {:error, :missing_email} ->
          conn
          |> put_flash(
            :error,
            "This account has no email address, so we cannot send a login code. Please contact support."
          )
          |> redirect(to: ~p"/user/login")

        {:error, {:cooldown, user}} ->
          conn
          |> start_verification(
            user,
            "A login code was just sent. Please use it or wait #{Accounts.login_code_resend_seconds()} seconds to resend."
          )
          |> redirect(to: ~p"/user/verify")

        {:error, {:rate_limited, user}} ->
          conn
          |> start_verification(
            user,
            "Too many login codes requested. Please try again later."
          )
          |> redirect(to: ~p"/user/verify")

        {:error, :delivery_failed} ->
          conn
          |> put_flash(:error, "We could not send the login email. Please try again in a moment.")
          |> redirect(to: ~p"/user/login")
      end
    end
  end

  @doc """
  Renders the one-time-code entry page for the pending login.
  """
  def verify(conn, _params) do
    case pending_login_user(conn) do
      %Accounts.User{} = user ->
        render(conn, :verify,
          masked_email: mask_email(user.email),
          resend_seconds: Accounts.login_code_resend_seconds(),
          ttl_minutes: Accounts.login_code_ttl_minutes()
        )

      _ ->
        conn
        |> put_flash(:error, "Please start signing in again.")
        |> redirect(to: ~p"/user/login")
    end
  end

  @doc """
  Checks the submitted one-time code and starts the session on success.
  """
  def confirm(conn, params) do
    code = get_in(params, ["user", "code"]) || params["code"] || ""

    case pending_login_user(conn) do
      %Accounts.User{} = user ->
        case Accounts.verify_login_code(user.id, to_string(code)) do
          {:ok, user} ->
            conn
            |> configure_session(renew: true)
            |> put_session(:user_id, user.id)
            |> delete_session(:login_user_id)
            |> delete_session(:login_identifier)
            |> put_flash(:success, "Welcome back!")
            |> redirect(to: ~p"/dashboard")

          {:error, reason} ->
            conn
            |> put_flash(:error, verify_error_message(reason))
            |> redirect(to: ~p"/user/verify")
        end

      _ ->
        conn
        |> put_flash(:error, "Your login code expired. Please start signing in again.")
        |> redirect(to: ~p"/user/login")
    end
  end

  @doc """
  Sends a fresh login code for the pending login (rate limited).
  """
  def resend(conn, _params) do
    case pending_login_user(conn) do
      %Accounts.User{} = user ->
        case Accounts.resend_login_code(user.id) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "A new login code was sent to #{mask_email(user.email)}.")
            |> redirect(to: ~p"/user/verify")

          {:error, {:cooldown, _user}} ->
            conn
            |> put_flash(
              :info,
              "A code was just sent. Please wait #{Accounts.login_code_resend_seconds()} seconds before requesting another."
            )
            |> redirect(to: ~p"/user/verify")

          {:error, _reason} ->
            conn
            |> put_flash(
              :error,
              "We could not send another login code. Please try again shortly."
            )
            |> redirect(to: ~p"/user/verify")
        end

      _ ->
        conn
        |> put_flash(:error, "Please start signing in again.")
        |> redirect(to: ~p"/user/login")
    end
  end

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.phone || user.id)
        |> put_flash(
          :success,
          "Registration successful! Welcome to Komiuta."
        )
        |> redirect(to: ~p"/dashboard")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, registration_error_message(changeset))
        |> render(:registration)
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: ~p"/")
  end

  defp start_verification(conn, user, message) do
    conn
    |> put_session(:login_user_id, user.id)
    |> put_session(:login_identifier, mask_email(user.email))
    |> put_flash(:info, message)
  end

  defp pending_login_user(conn) do
    case get_session(conn, :login_user_id) do
      user_id when is_binary(user_id) -> Accounts.get_user(user_id)
      _ -> nil
    end
  end

  defp verify_error_message(:expired), do: "That code has expired. Request a new one."

  defp verify_error_message(:too_many_attempts),
    do: "Too many incorrect attempts. Request a new code."

  defp verify_error_message(:invalid),
    do: "That code is not correct. Check the email and try again."

  defp verify_error_message(:no_code), do: "No active login code. Request a new one."
  defp verify_error_message(_), do: "That code could not be verified. Request a new one."

  defp registration_error_message(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {message, _opts} -> message end)

    cond do
      Map.has_key?(errors, :email) -> "Please enter a valid email address."
      Map.has_key?(errors, :phone) -> "That phone number is already registered."
      true -> "Registration failed. Please check your details and try again."
    end
  end

  # a***@example.com — avoids echoing the full address in the UI.
  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@", parts: 2) do
      [local, domain] when byte_size(local) > 0 ->
        visible = String.slice(local, 0, 2)
        hidden = String.duplicate("*", max(1, byte_size(local) - byte_size(visible)))
        visible <> hidden <> "@" <> domain

      _ ->
        email
    end
  end

  defp mask_email(_email), do: "your email"
end
