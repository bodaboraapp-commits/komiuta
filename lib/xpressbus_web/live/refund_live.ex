defmodule XpressbusWeb.RefundLive do
  use XpressbusWeb, :live_view

  import XpressbusWeb.BrandComponents

  alias Xpressbus.{Accounts, Payments, Refunds, TicketAccess, Tickets}

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Refund request & tracking")
     |> assign(:page_robots, "noindex,nofollow")
     |> assign(:page_description, "Request or track a refund for a KOMIUTA bus ticket.")
     |> assign(:step, :ticket)
     |> assign(:current_user, session["user_id"])
     |> assign(:ticket, nil)
     |> assign(:refund, nil)
     |> assign(:payment, nil)
     |> assign(:error, nil)
     |> assign(:form, to_form(%{"amount" => "", "reason" => "", "email" => ""}, as: :refund))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    ticket = Tickets.get_ticket(params["ticket_id"])

    cond do
      is_nil(ticket) or not TicketAccess.valid?(ticket, params["token"]) ->
        {:noreply,
         socket
         |> put_flash(:error, "That refund link is invalid or has expired.")
         |> push_navigate(to: ~p"/tickets")}

      true ->
        refund = Refunds.latest_for_ticket(ticket.ticket_id)
        payment = Payments.completed_payment_for_ticket(ticket.ticket_id)
        email = (Accounts.get_user_by_phone(ticket.passenger_phone) || %{email: ""}).email

        {:noreply,
         socket
         |> assign(:ticket, ticket)
         |> assign(:refund, refund)
         |> assign(:payment, payment)
         |> assign(
           :form,
           to_form(
             %{
               "amount" => ticket.price |> Tickets.parse_amount(),
               "reason" => "",
               "email" => email || ""
             },
             as: :refund
           )
         )
         |> assign(:page_title, "Refund #{ticket.ticket_id}")}
    end
  end

  @impl true
  def handle_event("request_refund", %{"refund" => params}, socket) do
    case Refunds.request_refund(socket.assigns.ticket, params) do
      {:ok, _refund} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Refund request received. We'll update you as it moves through review."
         )
         |> assign(:refund, Refunds.latest_for_ticket(socket.assigns.ticket.ticket_id))}

      {:error, reason} ->
        {:noreply, assign(socket, :error, error_message(reason))}
    end
  end

  def handle_event("accept_credit", _params, socket) do
    case Refunds.accept_credit(socket.assigns.ticket, socket.assigns.refund) do
      {:ok, refund} ->
        {:noreply,
         socket
         |> assign(:refund, Refunds.latest_for_ticket(refund.ticket_id))
         |> put_flash(:success, "Travel credit issued. Your code is #{refund.credit_code}.")}

      {:error, reason} ->
        {:noreply, assign(socket, :error, error_message(reason))}
    end
  end

  def handle_event("keep_booking", _params, socket) do
    case Refunds.keep_booking(socket.assigns.ticket, socket.assigns.refund) do
      {:ok, _refund} ->
        {:noreply,
         socket
         |> assign(:refund, Refunds.latest_for_ticket(socket.assigns.ticket.ticket_id))
         |> put_flash(:success, "Your booking remains in place. Safe travels!")}

      {:error, reason} ->
        {:noreply, assign(socket, :error, error_message(reason))}
    end
  end

  defp error_message(:already_requested),
    do: "There is already an open refund request for this ticket."

  defp error_message(:already_cancelled), do: "This ticket has already been cancelled."

  defp error_message(:payment_not_completed),
    do: "A refund can only be requested after a completed payment."

  defp error_message(:payment_confirmation_missing),
    do: "The payment confirmation code is missing. Please contact support."

  defp error_message(:reversal_code_required),
    do: "The payment company reversal code is required."

  defp error_message(:invalid_amount), do: "Enter a refund amount greater than zero."

  defp error_message(:amount_exceeds_paid),
    do: "The refund cannot be more than the amount paid for this ticket."

  defp error_message(:reason_required),
    do: "Tell us the reason for the refund (at least 5 characters)."

  defp error_message(:invalid_transition), do: "This refund request can no longer be changed."

  defp error_message(_reason),
    do: "That refund action could not be completed. Please contact support."
end
