defmodule Xpressbus.RefundEmail do
  @moduledoc """
  Customer-facing updates for the refund workflow.

  Every decision sends a plain-language status update. The email is best-effort:
  a failed delivery never rolls back a refund transition.
  """

  import Swoosh.Email

  alias Xpressbus.{Accounts, Mailer, TicketAccess}

  @subjects %{
    requested: "We received your refund request",
    approved: "Your refund has been approved",
    rejected: "Update on your refund request",
    refunded: "Your refund has been processed",
    retained: "Your travel credit is ready",
    withdrawn: "Your refund request was withdrawn"
  }

  def deliver(kind, ticket, refund) do
    customer = customer(ticket, refund)

    cond do
      is_nil(customer) ->
        {:error, :no_email}

      true ->
        email =
          new()
          |> to({customer.name, customer.email})
          |> from({"KOMIUTA", from_address()})
          |> subject(email_subject(kind, ticket))
          |> text_body(text_body(kind, customer.name, ticket, refund))
          |> html_body(html_body(kind, customer.name, ticket, refund))

        Mailer.deliver(email)
    end
  end

  def email_subject(kind, ticket) do
    "#{Map.get(@subjects, kind, "Refund update")} — #{ticket.ticket_id}"
  end

  defp customer(ticket, refund) do
    user = Accounts.get_user_by_phone(ticket.passenger_phone)
    email = refund.customer_email || (user && user.email)

    if is_binary(email) and String.trim(email) != "" do
      %{
        name: (user && user.name) || ticket.passenger_name || "traveller",
        email: String.trim(email)
      }
    end
  end

  defp text_body(kind, name, ticket, refund) do
    """
    Dear #{name},

    #{opening(kind, ticket, refund)}

    Ticket: #{ticket.ticket_id}
    Route: #{ticket.from} to #{ticket.to}
    Refund amount: #{money(refund.amount_approved || refund.amount)}
    Status: #{status(kind)}
    #{credit_line(refund)}
    Track this request: #{XpressbusWeb.Endpoint.url() <> TicketAccess.refund_path(ticket)}

    Questions? Reply to this email or call #{Xpressbus.Brand.phone()}.

    The KOMIUTA team
    #{Xpressbus.Brand.website_label()}
    """
  end

  defp html_body(kind, name, ticket, refund) do
    """
    <div style="font-family:Arial,sans-serif;max-width:580px;margin:0 auto;color:#0f172a">
      <div style="background:#FF4C00;color:white;padding:22px 26px;border-radius:18px 18px 0 0">
        <p style="margin:0;font-size:11px;font-weight:800;letter-spacing:2px;text-transform:uppercase">KOMIUTA refunds</p>
        <h1 style="margin:8px 0 0;font-size:24px">#{status(kind)}</h1>
      </div>
      <div style="border:1px solid #e2e8f0;border-top:0;padding:26px;border-radius:0 0 18px 18px">
        <p>Dear #{name},</p>
        <p>#{opening(kind, ticket, refund)}</p>
        <table style="width:100%;margin:20px 0;border-collapse:collapse">
          <tr><td style="padding:8px 0;color:#64748b">Ticket</td><td style="text-align:right;font-weight:700">#{ticket.ticket_id}</td></tr>
          <tr><td style="padding:8px 0;color:#64748b">Route</td><td style="text-align:right;font-weight:700">#{ticket.from} to #{ticket.to}</td></tr>
          <tr><td style="padding:8px 0;color:#64748b">Amount</td><td style="text-align:right;font-weight:700;color:#FF4C00">#{money(refund.amount_approved || refund.amount)}</td></tr>
          <tr><td style="padding:8px 0;color:#64748b">Status</td><td style="text-align:right;font-weight:700">#{status(kind)}</td></tr>
          #{credit_row(refund)}
        </table>
        <p><a href="#{XpressbusWeb.Endpoint.url() <> TicketAccess.refund_path(ticket)}" style="display:inline-block;background:#0f172a;color:white;text-decoration:none;padding:12px 18px;border-radius:10px;font-weight:700">Track this request</a></p>
        <p style="font-size:12px;color:#94a3b8">Questions? Reply to this email or call #{Xpressbus.Brand.phone()}.</p>
      </div>
    </div>
    """
  end

  defp opening(:requested, ticket, _refund),
    do:
      "We have your refund request for ticket #{ticket.ticket_id}. Our team will review it and update you here."

  defp opening(:approved, ticket, _refund),
    do:
      "Good news — your refund for ticket #{ticket.ticket_id} has been approved and is being prepared."

  defp opening(:rejected, ticket, _refund),
    do:
      "After reviewing ticket #{ticket.ticket_id}, we could not approve this refund. Our team has added a note, and support can help with alternatives."

  defp opening(:refunded, ticket, refund),
    do:
      "Your refund for ticket #{ticket.ticket_id} has been processed back to your original payment method. Reference: #{refund.reference || "will follow"}."

  defp opening(:retained, ticket, refund),
    do:
      "Thank you for staying with us. Your travel credit for ticket #{ticket.ticket_id} is ready: #{refund.credit_code || "contact support"}."

  defp opening(:withdrawn, ticket, _refund),
    do:
      "Your refund request for ticket #{ticket.ticket_id} has been withdrawn and your booking remains in place."

  defp opening(_kind, ticket, _refund),
    do: "There is an update on your refund request for ticket #{ticket.ticket_id}."

  defp status("requested"), do: "Request received"
  defp status("approved"), do: "Approved"
  defp status("rejected"), do: "Needs support"
  defp status("refunded"), do: "Refunded"
  defp status("retained"), do: "Travel credit issued"
  defp status("withdrawn"), do: "Booking retained"
  defp status(_kind), do: "Refund update"

  defp credit_line(%{credit_code: code}) when is_binary(code), do: "Travel credit: #{code}"
  defp credit_line(_refund), do: ""

  defp credit_row(%{credit_code: code}) when is_binary(code) do
    "<tr><td style=\"padding:8px 0;color:#64748b\">Travel credit</td><td style=\"text-align:right;font-weight:700\">#{code}</td></tr>"
  end

  defp credit_row(_refund), do: ""

  defp money(amount) when is_integer(amount), do: "KES #{amount}"
  defp money(amount), do: "KES #{amount}"

  defp from_address, do: Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")
end
