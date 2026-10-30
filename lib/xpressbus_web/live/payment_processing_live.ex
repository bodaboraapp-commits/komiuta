defmodule XpressbusWeb.PaymentProcessingLive do
  @moduledoc """
  Intermediary payment processing page.
  """

  use XpressbusWeb, :live_view
  require Logger
  alias Xpressbus.Payments
  alias Xpressbus.Tickets

  @impl true
  def mount(params, _session, socket) do
    ticket_id = Map.get(params, "ticket_id")
    payment_method = Map.get(params, "payment_method") || Map.get(params, "method") || "mpesa"

    Logger.info("PaymentProcessingLive mounted", %{
      ticket_id: ticket_id,
      payment_method: payment_method
    })

    socket =
      socket
      |> assign(:ticket_id, ticket_id)
      |> assign(:payment_method, payment_method)
      |> assign(:status, :processing)
      |> assign(:message, "Processing your payment...")
      |> assign(:ticket, nil)

    if ticket_id do
      Logger.info("Starting payment polling", %{ticket_id: ticket_id})
      {:ok, schedule_polling(socket)}
    else
      Logger.warning("No ticket_id provided, showing failed state")

      {:ok,
       socket
       |> assign(:status, :failed)
       |> assign(:message, "Missing payment reference.")}
    end
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    if socket.assigns.ticket do
      {:noreply,
       push_navigate(socket,
         to:
           "/tickets?ticket_id=#{socket.assigns.ticket.ticket_id}&last4=#{last4(socket.assigns.ticket.passenger_phone)}"
       )}
    else
      {:noreply, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_info(:poll_payment, socket) do
    ticket_id = socket.assigns.ticket_id
    Logger.info("Polling payment status", %{ticket_id: ticket_id})

    payment = Payments.get_payment_by_reference(ticket_id)
    # INDUSTRIAL BACKUP: Check if ticket already exists (means success in many flows)
    ticket = Tickets.get_ticket(ticket_id)

    cond do
      payment && payment.status == "success" ->
        Logger.info("Payment success found via payment record", %{ticket_id: ticket_id})
        handle_success(socket, ticket || Tickets.get_ticket(ticket_id))

      ticket && ticket.status == "confirmed" ->
        Logger.info("Payment success found via ticket record", %{ticket_id: ticket_id})
        handle_success(socket, ticket)

      payment && payment.status == "failed" ->
        Logger.info("Payment failed", %{ticket_id: ticket_id})

        {:noreply,
         socket
         |> assign(:status, :failed)
         |> assign(:message, "Payment failed. Please try again.")}

      payment && payment.status == "cancelled" ->
        Logger.info("Payment cancelled", %{ticket_id: ticket_id})

        {:noreply,
         socket
         |> assign(:status, :failed)
         |> assign(:message, "Payment was cancelled.")}

      true ->
        Logger.info("Payment still pending, continuing to poll", %{
          ticket_id: ticket_id,
          status: if(payment, do: payment.status, else: "not_found"),
          ticket_exists: not is_nil(ticket)
        })

        {:noreply, schedule_polling(socket)}
    end
  end

  @impl true
  def handle_info(:auto_navigate, socket) do
    if socket.assigns.ticket do
      {:noreply,
       push_navigate(socket,
         to:
           "/tickets?ticket_id=#{socket.assigns.ticket.ticket_id}&last4=#{last4(socket.assigns.ticket.passenger_phone)}"
       )}
    else
      {:noreply, socket}
    end
  end

  defp last4(nil), do: ""

  defp last4(phone) do
    digits = String.replace(to_string(phone), ~r/[^0-9]/, "")
    if byte_size(digits) >= 4, do: String.slice(digits, -4, 4), else: ""
  end

  defp handle_success(socket, ticket) do
    # INDUSTRIAL AUTO-NAVIGATE: Unblock the traveler immediately upon confirmation
    Process.send_after(self(), :auto_navigate, 2500)

    {:noreply,
     socket
     |> assign(:status, :success)
     |> assign(:message, "Payment successful!")
     |> assign(:ticket, ticket)
     |> put_flash(:info, "Payment completed successfully")}
  end

  defp schedule_polling(socket) do
    Process.send_after(self(), :poll_payment, 2000)
    socket
  end
end
