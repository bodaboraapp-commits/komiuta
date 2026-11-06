defmodule XpressbusWeb.AdminTicketsLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents

  alias Xpressbus.Tickets

  @page_size 15

  def mount(_params, session, socket) do
    if admin_id = session["admin_id"] do
      socket =
        socket
        |> assign(:page_title, "Tickets")
        |> assign(:active_tab, "tickets")
        |> assign(:admin_id, admin_id)
        |> assign(:page_size, @page_size)
        |> assign(:search, "")
        |> assign(:selected_ticket, nil)
        |> assign(:refund_amount, "")
        |> assign(:sms_configured, Xpressbus.SMS.configured?())
        |> assign(:sidebar_collapsed, false)
        |> assign(:bus_expanded, true)
        |> assign(:chyllz_expanded, true)
        |> assign(:settings_expanded, true)
        |> load_tickets(1, "")

      {:ok, socket}
    else
      {:ok, Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("search", %{"search" => search}, socket) do
    search = to_string(search || "")
    {:noreply, socket |> assign(:search, search) |> load_tickets(1, search)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = page |> to_string() |> String.to_integer() |> max(1)
    {:noreply, load_tickets(socket, page, socket.assigns.search)}
  end

  def handle_event("open_cancel", %{"ticket_id" => ticket_id}, socket) do
    case Tickets.get_ticket(ticket_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Ticket not found.")}

      ticket ->
        {:noreply,
         socket
         |> assign(:selected_ticket, ticket)
         |> assign(:refund_amount, default_refund_amount(ticket))}
    end
  end

  def handle_event("close_cancel", _params, socket) do
    {:noreply, assign(socket, :selected_ticket, nil)}
  end

  def handle_event(
        "cancel_ticket",
        %{"ticket_id" => ticket_id, "refund" => refund_params},
        socket
      ) do
    case Tickets.get_ticket(ticket_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Ticket not found.")}

      ticket ->
        result =
          Tickets.cancel_and_refund(
            ticket,
            %{
              refund_amount: refund_params["amount"],
              reason: refund_params["reason"],
              reference: refund_params["reference"]
            },
            socket.assigns.admin_id
          )

        case result do
          {:ok, %{ticket: cancelled, refund: refund, email: email, sms: sms}} ->
            {:noreply,
             socket
             |> put_flash(
               :info,
               "Ticket #{cancelled.ticket_id} cancelled. Refund KES #{refund.amount}. Email: #{notification_label(email)}. SMS: #{notification_label(sms)}."
             )
             |> assign(:selected_ticket, nil)
             |> assign(:sms_configured, Xpressbus.SMS.configured?())
             |> load_tickets(1, socket.assigns.search)}

          {:error, :already_cancelled} ->
            {:noreply, put_flash(socket, :error, "This ticket has already been cancelled.")}

          {:error, :invalid_amount} ->
            {:noreply, put_flash(socket, :error, "Enter a valid refund amount.")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Could not cancel the ticket: #{inspect(changeset.errors)}"
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(socket, :error, "Could not cancel the ticket: #{inspect(reason)}")}
        end
    end
  end

  def handle_event("toggle_bus", %{"category" => "bus"}, socket) do
    {:noreply, assign(socket, :bus_expanded, !socket.assigns.bus_expanded)}
  end

  def handle_event("toggle_chyllz", %{"category" => "chyllz"}, socket) do
    {:noreply, assign(socket, :chyllz_expanded, !socket.assigns.chyllz_expanded)}
  end

  def handle_event("toggle_settings", %{"category" => "settings"}, socket) do
    {:noreply, assign(socket, :settings_expanded, !socket.assigns.settings_expanded)}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  defp load_tickets(socket, page, search) do
    {tickets, total_count} =
      Tickets.paginate_admin_tickets(page, socket.assigns.page_size, search)

    socket
    |> assign(:tickets, tickets)
    |> assign(:total_count, total_count)
    |> assign(:page, page)
    |> assign(:total_pages, max(1, ceil(total_count / socket.assigns.page_size)))
  end

  defp default_refund_amount(ticket) do
    amount =
      case Integer.parse(String.replace(ticket.price || "", ~r/[^0-9]/, "")) do
        {amount, _} -> amount
        :error -> ""
      end

    to_string(amount)
  end

  defp notification_label({:ok, _}), do: "sent"
  defp notification_label({:error, :no_email}), do: "no email on account"
  defp notification_label({:error, :not_configured}), do: "SMS not configured"
  defp notification_label({:error, :no_user}), do: "no account email"
  defp notification_label({:error, :invalid_phone}), do: "invalid phone"
  defp notification_label({:error, reason}), do: to_string(reason)
  defp notification_label(_), do: "not sent"
end
