defmodule XpressbusWeb.UserDashboardLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents
  alias Xpressbus.{Repo, Tickets, Accounts}
  alias Xpressbus.Tickets.Ticket
  import Ecto.Query

  def mount(_params, session, socket) do
    user_id_or_phone = session["user_id"]

    if user_id_or_phone do
      # Robust User Resolution: Handles both UUID (Google) and Phone (Legacy)
      user =
        cond do
          # Check if it's a valid UUID (Google users use UUID as session key)
          String.match?(
            user_id_or_phone,
            ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
          ) ->
            Accounts.get_user(user_id_or_phone)

          true ->
            # Legacy/Standard users use Phone as session key
            Accounts.get_user_by_phone(user_id_or_phone)
        end

      if user do
        if Accounts.profile_complete?(user) do
          tickets = list_user_tickets(user.phone)
          transactions = Accounts.list_user_transactions(user.id)

          {:ok,
           socket
           |> assign(:page_title, "My Dashboard")
           |> assign(:active_tab, "bus")
           |> assign(:user, user)
           |> assign(:current_user, user.phone)
           |> assign(:tickets, tickets)
           |> assign(:transactions, transactions)
           |> assign(:selected_ticket, nil)
           |> assign(:show_ticket_modal, false)
           |> assign(:show_phone_modal, false)
           |> assign(:phone_error, nil)
           |> assign(:profile_form, Accounts.change_user(user) |> to_form())
           |> assign(:show_email_change_modal, false)
           |> assign(:email_change_step, :email)
           |> assign(:email_change_form, to_form(%{"new_email" => ""}))
           |> assign(:email_change_error, nil)
           |> assign(:pending_new_email, nil)
           |> assign(:footer_tab, "about")}
        else
          # Every account must have both a phone number and an email before the
          # dashboard (and its personal data) is shown.
          {:ok,
           socket
           |> Phoenix.LiveView.redirect(to: ~p"/user/complete-profile")}
        end
      else
        {:ok, redirect(socket, to: ~p"/user/login")}
      end
    else
      {:ok,
       socket
       |> assign(:page_title, "My Dashboard")
       |> Phoenix.LiveView.redirect(to: ~p"/user/login")}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("view_ticket", %{"ticket_id" => ticket_id}, socket) do
    user = socket.assigns.user

    ticket =
      case Tickets.get_ticket(ticket_id) do
        nil -> nil
        ticket -> if ticket_belongs_to_user?(ticket, user), do: ticket, else: nil
      end

    if ticket do
      {:noreply,
       socket
       |> assign(:selected_ticket, ticket)
       |> assign(:show_ticket_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "Ticket not found on your account.")}
    end
  end

  def handle_event("close_ticket", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_ticket, nil)
     |> assign(:show_ticket_modal, false)}
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    # The email address is deliberately not editable here: changing it requires
    # a code sent to the new address (see request_email_change below).
    user_params = Map.drop(user_params, ["email"])

    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:profile_form, Accounts.change_user(user) |> to_form())
         |> put_flash(:info, "Profile updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  def handle_event("open_email_change", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_email_change_modal, true)
     |> assign(:email_change_step, :email)
     |> assign(:email_change_form, to_form(%{"new_email" => ""}))
     |> assign(:email_change_error, nil)
     |> assign(:pending_new_email, nil)}
  end

  def handle_event("close_email_change", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_email_change_modal, false)
     |> assign(:email_change_step, :email)
     |> assign(:email_change_form, to_form(%{"new_email" => ""}))
     |> assign(:email_change_error, nil)
     |> assign(:pending_new_email, nil)}
  end

  def handle_event("request_email_change", %{"email_change" => params}, socket) do
    new_email = params |> Map.get("new_email", "") |> to_string()

    case Accounts.request_email_change(socket.assigns.user, new_email) do
      {:ok, %{new_email: pending}} ->
        {:noreply,
         socket
         |> assign(:email_change_step, :code)
         |> assign(:pending_new_email, pending)
         |> assign(:email_change_error, nil)
         |> put_flash(:info, "We emailed a 6-digit code to #{pending}.")}

      {:error, reason} ->
        {:noreply, assign(socket, :email_change_error, email_change_error(reason))}
    end
  end

  def handle_event("confirm_email_change", %{"code" => code}, socket) do
    case Accounts.verify_email_change(socket.assigns.user, to_string(code)) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:profile_form, Accounts.change_user(user) |> to_form())
         |> assign(:show_email_change_modal, false)
         |> assign(:email_change_step, :email)
         |> assign(:pending_new_email, nil)
         |> assign(:email_change_error, nil)
         |> put_flash(:info, "Email address updated successfully.")}

      {:error, reason} ->
        {:noreply, assign(socket, :email_change_error, email_change_error(reason))}
    end
  end

  def handle_event("save_missing_phone", %{"phone" => phone}, socket) do
    phone = String.trim(phone || "")

    cond do
      phone == "" ->
        {:noreply, assign(socket, :phone_error, "Phone number is required.")}

      not Regex.match?(~r/^(07|01|254)\d{8}$/, phone) ->
        {:noreply, assign(socket, :phone_error, "Please enter a valid Kenyan phone number.")}

      Accounts.get_user_by_phone(phone) ->
        {:noreply,
         assign(socket, :phone_error, "This phone number is already linked to another account.")}

      true ->
        case Accounts.update_user(socket.assigns.user, %{phone: phone}) do
          {:ok, user} ->
            {:noreply,
             socket
             |> assign(:user, user)
             |> assign(:current_user, user.phone)
             |> assign(:show_phone_modal, false)
             |> put_flash(:info, "Phone number updated successfully.")}

          {:error, _changeset} ->
            {:noreply, assign(socket, :phone_error, "Failed to update phone number.")}
        end
    end
  end

  def handle_event("referral_copied", _params, socket) do
    {:noreply, put_flash(socket, :info, "Referral code copied to clipboard.")}
  end

  def handle_event("referral_copy_failed", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Could not copy automatically. Long-press the code to copy it."
     )}
  end

  def handle_event("wallet_action", %{"action" => action}, socket) do
    message =
      case action do
        "top-up" ->
          "Wallet top-up is coming soon. For now, pay for each ticket directly at checkout."

        "transfer" ->
          "Wallet transfers are coming soon."

        "change-payment-method" ->
          "You can choose a payment method on every booking at checkout."

        _ ->
          "This feature is coming soon."
      end

    {:noreply, put_flash(socket, :info, message)}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  defp ticket_belongs_to_user?(ticket, user) do
    identity = user.phone

    is_binary(identity) and identity != "" and
      (ticket.passenger_phone == identity or ticket.passenger_name == identity)
  end

  defp list_user_tickets(phone) do
    from(t in Ticket,
      where: t.passenger_phone == ^phone or t.passenger_name == ^phone,
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(&Tickets.deserialize_seats/1)
  end

  defp format_date(nil), do: ""
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%B %d, %Y")
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y • %I:%M %p")

  defp format_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Calendar.strftime(date, "%B %d, %Y")
      _ -> date_string
    end
  end

  defp format_seats(nil), do: ""
  defp format_seats(seats) when is_list(seats), do: Enum.join(seats, ", ")

  defp format_seats(seats) when is_binary(seats) do
    case Jason.decode(seats) do
      {:ok, decoded_list} when is_list(decoded_list) -> Enum.join(decoded_list, ", ")
      _ -> seats
    end
  end

  defp email_change_error(reason) do
    case reason do
      :invalid_email ->
        "Enter a valid email address."

      :same_email ->
        "That is already your account email."

      :taken ->
        "That email is already linked to another account."

      :delivery_failed ->
        "We could not send the verification email. Please try again."

      :no_code ->
        "Request a new verification code."

      :expired ->
        "That code has expired. Request a new one."

      :too_many_attempts ->
        "Too many incorrect attempts. Request a new code."

      :invalid ->
        "That code is not correct. Check the new email address and try again."

      :failed ->
        "We could not update your email. Please try again."

      {:cooldown, _user} ->
        "A code was just sent. Please wait #{Accounts.email_change_resend_seconds()} seconds before requesting another."

      {:rate_limited, _user} ->
        "Too many email-change requests. Please try again later."

      _reason ->
        "Something went wrong. Please try again."
    end
  end
end
