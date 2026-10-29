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
        tickets = list_user_tickets(user.phone)
        transactions = Accounts.list_user_transactions(user.id)

        # Gmail users with placeholder phones start with "G-"
        show_phone_modal = String.starts_with?(user.phone || "", "G-")

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
         |> assign(:show_phone_modal, show_phone_modal)
         |> assign(:phone_error, nil)
         |> assign(:profile_form, Accounts.change_user(user) |> to_form())
         |> assign(:footer_tab, "about")}
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
    ticket =
      Tickets.get_ticket!(ticket_id)
      |> Tickets.deserialize_seats()
      |> Repo.preload(:bus)

    {:noreply,
     socket
     |> assign(:selected_ticket, ticket)
     |> assign(:show_ticket_modal, true)}
  end

  def handle_event("close_ticket", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_ticket, nil)
     |> assign(:show_ticket_modal, false)}
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
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

  def handle_event("copy_referral", _, socket) do
    {:noreply, put_flash(socket, :info, "Referral code copied to clipboard!")}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
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
end
