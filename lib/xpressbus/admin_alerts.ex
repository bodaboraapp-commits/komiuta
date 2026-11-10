defmodule Xpressbus.AdminAlerts do
  @moduledoc """
  Operational alerts for the KOMIUTA team.

  Booking and payment alerts go to the configured comms inbox(es) only. They are
  deliberately separate from the admin login accounts, so changing who receives
  alerts never changes who can sign in to the admin console.
  """

  require Logger

  alias Xpressbus.AdminAlertEmail
  alias Xpressbus.Payments
  alias Xpressbus.Tickets.Ticket

  @doc "The configured alert recipients, as a list of email addresses."
  def recipients do
    :xpressbus
    |> Application.get_env(:admin_alert_emails, [])
    |> normalise_recipients()
  end

  @doc """
  Sends a new-booking alert in the background.

  When the ticket already has a successful payment, the same email also reports
  the payment as received.
  """
  def booking_created(%Ticket{} = ticket) do
    deliver_async(fn -> deliver_booking(ticket) end)
  end

  @doc "Sends a payment-received alert for a ticket that already existed."
  def payment_received(payment, %Ticket{} = ticket) do
    deliver_async(fn -> deliver_payment(payment, ticket) end)
  end

  @doc "Synchronous booking alert, useful for tests and manual resend tools."
  def deliver_booking(%Ticket{} = ticket) do
    payment = payment_for(ticket)
    AdminAlertEmail.deliver(ticket, payment)
  end

  @doc "Synchronous payment-received alert."
  def deliver_payment(payment, %Ticket{} = ticket) do
    AdminAlertEmail.deliver_payment(ticket, payment)
  end

  defp payment_for(%Ticket{ticket_id: ticket_id}) when is_binary(ticket_id) do
    Payments.get_payment_by_reference(ticket_id)
  end

  defp payment_for(_ticket), do: nil

  defp deliver_async(fun) do
    if recipients() == [] do
      :ok
    else
      _ = Task.start(fn -> safely(fun) end)
      :ok
    end
  end

  defp safely(fun) do
    fun.()
  rescue
    error ->
      Logger.warning("Admin alert delivery failed: #{Exception.message(error)}")
      :error
  catch
    kind, reason ->
      Logger.warning("Admin alert delivery failed: #{inspect({kind, reason})}")
      :error
  end

  defp normalise_recipients(value) when is_list(value) do
    value
    |> Enum.map(&normalise_recipient/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalise_recipients(value) when is_binary(value) do
    value
    |> String.split([",", ";"], trim: true)
    |> normalise_recipients()
  end

  defp normalise_recipients(_value), do: []

  defp normalise_recipient(value) do
    email = value |> to_string() |> String.trim()

    if email == "" or not String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
      nil
    else
      email
    end
  end
end
