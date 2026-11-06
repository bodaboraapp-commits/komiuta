defmodule Xpressbus.TicketCancellationEmail do
  @moduledoc """
  Apology email sent to a traveller after an admin cancels and refunds a ticket.
  """

  import Swoosh.Email

  alias Xpressbus.Mailer

  def build(user, ticket, refund) do
    name = display_name(user, ticket)
    logo_url = XpressbusWeb.Endpoint.url() <> "/images/logo_email.png"
    website = Xpressbus.Brand.website_label()
    support_email = Xpressbus.Brand.email()
    phone = Xpressbus.Brand.phone()

    new()
    |> to({name, user.email})
    |> from({"Komiuta", from_address()})
    |> subject("Our apologies — your Komiuta ticket #{ticket.ticket_id} was cancelled")
    |> text_body(text_body(name, ticket, refund, website, support_email, phone))
    |> html_body(html_body(name, ticket, refund, logo_url, website, support_email, phone))
  end

  def deliver(user, ticket, refund) do
    if is_nil(user) or is_nil(user.email) or String.trim(to_string(user.email)) == "" do
      {:error, :no_email}
    else
      user
      |> build(ticket, refund)
      |> Mailer.deliver()
    end
  end

  defp from_address do
    Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")
  end

  defp display_name(user, ticket) do
    [user && user.name, ticket.passenger_name]
    |> Enum.find(fn value -> is_binary(value) and String.trim(value) != "" end)
    |> case do
      nil -> "traveller"
      value -> value
    end
  end

  defp route(ticket), do: "#{ticket.from} to #{ticket.to}"

  defp travel_date(ticket) do
    case ticket.travel_date do
      %Date{} = date -> Calendar.strftime(date, "%A, %d %B %Y")
      _ -> "your travel date"
    end
  end

  defp money(amount) when is_integer(amount), do: "KES #{amount}"
  defp money(amount), do: "KES #{amount}"

  defp text_body(name, ticket, refund, website, support_email, phone) do
    """
    Dear #{name},

    We are very sorry to let you know that your Komiuta ticket #{ticket.ticket_id}
    for #{route(ticket)} on #{travel_date(ticket)} has been cancelled.

    A refund of #{money(refund.amount)} is being processed back to your original
    payment method. Refund reference: #{refund.reference || "will be shared shortly"}.

    We sincerely apologise for the inconvenience. If you need help rebooking or
    have any questions, please contact us at #{support_email} or #{phone}.

    With apologies,
    The Komiuta team
    #{website}
    """
  end

  defp html_body(name, ticket, refund, logo_url, website, support_email, phone) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Your Komiuta ticket was cancelled</title>
      </head>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:24px 12px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:24px;overflow:hidden;border:1px solid #e2e8f0;">
                <tr>
                  <td style="background:#FF4C00;height:6px;font-size:0;line-height:0;">&nbsp;</td>
                </tr>
                <tr>
                  <td style="padding:28px 32px 0;">
                    <img src="#{logo_url}" alt="Komiuta" width="146" height="40" style="display:block;border:0;" />
                  </td>
                </tr>
                <tr>
                  <td style="padding:24px 32px 8px;">
                    <p style="margin:0 0 8px;font-size:11px;font-weight:800;letter-spacing:2px;text-transform:uppercase;color:#FF4C00;">Ticket cancellation</p>
                    <h1 style="margin:0;font-size:26px;line-height:1.25;color:#0f172a;">We're sorry, #{name}.</h1>
                    <p style="margin:14px 0 0;font-size:15px;line-height:1.7;color:#475569;">
                      Your ticket <strong>#{ticket.ticket_id}</strong> for <strong>#{route(ticket)}</strong>
                      on <strong>#{travel_date(ticket)}</strong> has been cancelled. We sincerely apologise
                      for the inconvenience this causes you.
                    </p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:20px 32px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:16px;">
                      <tr>
                        <td style="padding:18px 20px;">
                          <p style="margin:0;font-size:11px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase;color:#94a3b8;">Refund</p>
                          <p style="margin:6px 0 0;font-size:24px;font-weight:800;color:#0f172a;">#{money(refund.amount)}</p>
                          <p style="margin:8px 0 0;font-size:13px;color:#64748b;">Refund reference: <strong>#{refund.reference || "will be shared shortly"}</strong></p>
                          <p style="margin:6px 0 0;font-size:13px;color:#64748b;">The refund is being returned to your original payment method.</p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 32px 24px;">
                    <p style="margin:0;font-size:14px;line-height:1.7;color:#475569;">
                      If you'd like help rebooking or have any questions, reply to this email or call us on
                      <strong>#{phone}</strong> / <a href="mailto:#{support_email}" style="color:#FF4C00;">#{support_email}</a>.
                    </p>
                    <p style="margin:18px 0 0;font-size:14px;color:#64748b;">With apologies,<br /><strong style="color:#0f172a;">The Komiuta team</strong></p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:18px 32px 28px;border-top:1px solid #e2e8f0;text-align:center;font-size:12px;color:#94a3b8;">
                    #{website} &middot; #{support_email} &middot; #{phone}
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end
end
