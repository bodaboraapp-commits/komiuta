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
            conn =
              conn
              |> configure_session(renew: true)
              |> put_session(:user_id, user.id)
              |> delete_session(:login_user_id)
              |> delete_session(:login_identifier)

            if Accounts.profile_complete?(user) do
              conn
              |> put_flash(:success, "Welcome back!")
              |> redirect(to: ~p"/dashboard")
            else
              conn
              |> put_flash(:info, "One last step: add your phone number to finish setting up.")
              |> redirect(to: ~p"/user/complete-profile")
            end

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
        conn =
          conn
          |> configure_session(renew: true)
          |> put_session(:user_id, user.id)
          |> put_session(:user_name, user.name)

        if Accounts.profile_complete?(user) do
          conn
          |> put_flash(:success, "Registration successful! Welcome to Komiuta.")
          |> redirect(to: ~p"/dashboard")
        else
          conn
          |> put_flash(:info, "One last step: add your phone number to finish setting up.")
          |> redirect(to: ~p"/user/complete-profile")
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, registration_error_message(changeset))
        |> render(:registration)
    end
  end

  @doc """
  Mandatory contact-details step: every account must have both a phone number
  and an email before the dashboard is shown.
  """
  def complete_profile(conn, _params) do
    case signed_in_user(conn) do
      %Accounts.User{} = user ->
        if Accounts.profile_complete?(user) do
          redirect(conn, to: ~p"/dashboard")
        else
          render(conn, :complete_profile,
            form: user |> Accounts.change_complete_profile() |> Phoenix.Component.to_form(),
            user: user,
            show_email_field: not Accounts.valid_email?(user.email)
          )
        end

      _ ->
        conn
        |> put_flash(:error, "Please sign in to continue.")
        |> redirect(to: ~p"/user/login")
    end
  end

  def save_complete_profile(conn, %{"user" => params}) do
    case signed_in_user(conn) do
      %Accounts.User{} = user ->
        case Accounts.complete_profile(user, params) do
          {:ok, user} ->
            conn
            |> put_session(:user_id, user.id)
            |> put_session(:user_name, user.name)
            |> put_flash(:success, "You're all set — welcome to Komiuta!")
            |> redirect(to: ~p"/dashboard")

          {:error, %Ecto.Changeset{} = changeset} ->
            email = Ecto.Changeset.get_field(changeset, :email)

            conn
            |> put_flash(:error, "Please check the highlighted fields.")
            |> render(:complete_profile,
              form: Phoenix.Component.to_form(changeset),
              user: user,
              show_email_field: not Accounts.valid_email?(email)
            )
        end

      _ ->
        conn
        |> put_flash(:error, "Please sign in to continue.")
        |> redirect(to: ~p"/user/login")
    end
  end

  defp signed_in_user(conn) do
    case get_session(conn, :user_id) do
      nil -> nil
      id -> Accounts.get_user(id)
    end
  end

  defp ticket_owner?(ticket, user) do
    passenger = phone_digits(ticket.passenger_phone)
    passenger != "" and passenger == phone_digits(user.phone)
  end

  defp phone_digits(nil), do: ""

  defp phone_digits(phone) do
    digits = phone |> to_string() |> String.replace(~r/\D/, "")
    if String.length(digits) > 9, do: String.slice(digits, -9, 9), else: digits
  end

  @doc """
  Downloads a ticket as a PDF. Only the passenger who owns the ticket (same phone
  number as their account) may download it.
  """
  def ticket_download(conn, %{"ticket_id" => ticket_id}) do
    case signed_in_user(conn) do
      %Accounts.User{} = user ->
        case Xpressbus.Tickets.get_ticket(ticket_id) do
          nil ->
            conn
            |> put_flash(:error, "Ticket not found.")
            |> redirect(to: ~p"/dashboard")

          ticket ->
            if ticket_owner?(ticket, user) do
              pdf = Xpressbus.TicketPDF.render(ticket)

              send_download(conn, {:binary, pdf},
                filename: "#{ticket.ticket_id}.pdf",
                content_type: "application/pdf"
              )
            else
              conn
              |> put_flash(:error, "That ticket does not belong to your account.")
              |> redirect(to: ~p"/dashboard")
            end
        end

      _ ->
        conn
        |> put_flash(:error, "Please sign in to continue.")
        |> redirect(to: ~p"/user/login")
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
