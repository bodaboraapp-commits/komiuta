defmodule Xpressbus.AdminAlertEmail do
  @moduledoc """
  Email templates for operational booking/payment alerts.
  """

  import Swoosh.Email

  alias Xpressbus.AdminAlerts
  alias Xpressbus.Brand
  alias Xpressbus.Mailer

  @doc "Sends a new-booking alert (including payment details when available)."
  def deliver(ticket, payment \\ nil) do
    case recipients() do
      [] ->
        :ok

      recipients ->
        send_email(
          recipients,
          booking_subject(ticket, payment),
          booking_body(ticket, payment),
          booking_html(ticket, payment)
        )
    end
  end

  @doc "Sends an alert for a successful payment."
  def deliver_payment(ticket, payment) do
    case recipients() do
      [] ->
        :ok

      recipients ->
        send_email(
          recipients,
          "Payment received — #{ticket.ticket_id}",
          payment_body(ticket, payment),
          payment_html(ticket, payment)
        )
    end
  end

  defp send_email(recipients, subject, text, html) do
    email =
      Swoosh.Email.new()
      |> to(recipients)
      |> from({"Komiuta Alerts", from_address()})
      |> subject(subject)
      |> text_body(text)
      |> html_body(html)

    case Mailer.deliver(email) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp booking_subject(ticket, payment) do
    if paid?(payment) do
      "New booking & payment received — #{ticket.ticket_id}"
    else
      "New booking — #{ticket.ticket_id}"
    end
  end

  defp booking_body(ticket, payment) do
    """
    New booking on Komiuta

    Ticket: #{ticket.ticket_id}
    Route: #{ticket.from} -> #{ticket.to}
    Travel: #{date(ticket.travel_date)} #{ticket.departure}
    Seats: #{ticket.seats}
    Passenger: #{ticket.passenger_name} (#{ticket.passenger_phone})
    Operator: #{ticket.company}
    Fare: #{ticket.price}
    Booking status: #{ticket.status}
    #{payment_line(payment)}
    Booked: #{datetime(ticket.inserted_at)}
    #{text_footer()}
    """
  end

  defp booking_html(ticket, payment) do
    body(
      if(paid?(payment), do: "New booking & payment received", else: "New booking"),
      """
      <p style="margin:0 0 16px;font-size:14px;color:#475569;">A new booking was created on Komiuta.</p>
      #{details_table(ticket)}
      #{payment_block(payment)}
      <p style="margin:20px 0 0;font-size:12px;color:#94a3b8;">Booked #{datetime(ticket.inserted_at)}</p>
      """
    )
  end

  defp payment_body(ticket, payment) do
    """
    Payment received on Komiuta

    Ticket: #{ticket.ticket_id}
    Route: #{ticket.from} -> #{ticket.to}
    Passenger: #{ticket.passenger_name} (#{ticket.passenger_phone})
    Amount: #{payment_amount(payment)}
    Provider: #{payment.provider}
    Payment reference: #{payment.reference}
    Payment status: #{payment.status}
    #{booking_link(ticket)}
    #{text_footer()}
    """
  end

  defp payment_html(ticket, payment) do
    body(
      "Payment received",
      """
      <p style="margin:0 0 16px;font-size:14px;color:#475569;">A payment was received for a Komiuta booking.</p>
      #{details_table(ticket)}
      #{payment_block(payment)}
      #{booking_link(ticket)}
      """
    )
  end

  defp details_table(ticket) do
    """
    <table style="width:100%;border-collapse:collapse;font-size:13px;color:#334155;">
      <tr><td style="padding:7px 0;color:#94a3b8;">Ticket</td><td style="padding:7px 0;font-weight:700;">#{h(ticket.ticket_id)}</td></tr>
      <tr><td style="padding:7px 0;color:#94a3b8;">Route</td><td style="padding:7px 0;font-weight:700;">#{h(ticket.from)} &rarr; #{h(ticket.to)}</td></tr>
      <tr><td style="padding:7px 0;color:#94a3b8;">Travel</td><td style="padding:7px 0;font-weight:700;">#{date(ticket.travel_date)} &middot; #{h(ticket.departure)}</td></tr>
      <tr><td style="padding:7px 0;color:#94a3b8;">Seats</td><td style="padding:7px 0;font-weight:700;">#{h(ticket.seats)}</td></tr>
      <tr><td style="padding:7px 0;color:#94a3b8;">Passenger</td><td style="padding:7px 0;font-weight:700;">#{h(ticket.passenger_name)} &middot; #{h(ticket.passenger_phone)}</td></tr>
      <tr><td style="padding:7px 0;color:#94a3b8;">Operator</td><td style="padding:7px 0;font-weight:700;">#{h(ticket.company)}</td></tr>
      <tr><td style="padding:7px 0;color:#94a3b8;">Fare</td><td style="padding:7px 0;font-weight:700;">#{h(ticket.price)}</td></tr>
      <tr><td style="padding:7px 0;color:#94a3b8;">Status</td><td style="padding:7px 0;font-weight:700;">#{h(ticket.status)}</td></tr>
    </table>
    """
  end

  defp payment_block(nil) do
    """
    <div style="margin-top:16px;padding:12px 14px;border-radius:12px;background:#f8fafc;font-size:12px;color:#64748b;">
      Payment has not been confirmed yet.
    </div>
    """
  end

  defp payment_block(payment) do
    """
    <div style="margin-top:16px;padding:12px 14px;border-radius:12px;background:#ecfdf5;font-size:12px;color:#166534;">
      <strong>Payment #{h(payment.status)}:</strong> #{payment_amount(payment)} via #{h(payment.provider)}<br />
      Reference: #{h(payment.reference)}
    </div>
    """
  end

  defp payment_line(nil), do: "Payment: not confirmed yet"

  defp payment_line(payment),
    do:
      "Payment: #{payment.status} — #{payment_amount(payment)} via #{payment.provider} (#{payment.reference})"

  defp booking_link(ticket) do
    url =
      XpressbusWeb.Endpoint.url() <>
        "/tickets?ticket_id=" <> URI.encode_www_form(ticket.ticket_id)

    """
    <p style="margin:20px 0 0;font-size:12px;color:#64748b;">View ticket: <a href="#{url}" style="color:#FF4C00;">#{url}</a></p>
    """
  end

  defp body(heading, content) do
    """
    <div style="font-family:Arial,sans-serif;max-width:620px;margin:0 auto;padding:24px;background:#ffffff;">
      <div style="background:#ffffff;padding:16px 22px;border:1px solid #f1f5f9;border-bottom:0;border-radius:14px 14px 0 0;">
        <img src="#{logo_url()}" alt="Komiuta" width="146" height="40" style="display:block;height:40px;width:auto;border:0;" />
      </div>
      <div style="background:#FF4C00;color:#ffffff;padding:18px 22px;">
        <p style="margin:0;font-size:11px;letter-spacing:2px;text-transform:uppercase;opacity:.8;">Komiuta operations</p>
        <h1 style="margin:4px 0 0;font-size:22px;">#{heading}</h1>
      </div>
      <div style="border:1px solid #f1f5f9;border-top:0;border-radius:0 0 14px 14px;padding:22px;">
        #{content}
        #{html_footer()}
      </div>
    </div>
    """
  end

  defp html_footer do
    social_html =
      Brand.social_links()
      |> Enum.map_join(" &nbsp;·&nbsp; ", fn %{name: name, url: url} ->
        ~s(<a href="#{h(url)}" target="_blank" rel="noopener" style="color:#FF4C00;text-decoration:none;">#{h(name)}</a>)
      end)

    """
    <div style="margin-top:22px;padding-top:16px;border-top:1px solid #f1f5f9;text-align:center;font-size:11px;line-height:1.7;color:#94a3b8;">
      <p style="margin:0 0 6px;">
        <a href="#{h(Brand.website())}" target="_blank" rel="noopener" style="color:#FF4C00;text-decoration:none;">#{h(Brand.website_label())}</a>
        &nbsp;·&nbsp;
        <a href="mailto:#{h(Brand.email())}" style="color:#FF4C00;text-decoration:none;">#{h(Brand.email())}</a>
        &nbsp;·&nbsp;
        <a href="#{h(Brand.phone_uri())}" style="color:#FF4C00;text-decoration:none;">#{h(Brand.phone())}</a>
      </p>
      <p style="margin:0;">Follow us: #{social_html}</p>
      <p style="margin:6px 0 0;color:#cbd5e1;">Komiuta · Elevate Your Journey</p>
    </div>
    """
  end

  defp text_footer do
    social =
      Enum.map_join(Brand.social_links(), " · ", fn %{name: name, url: url} ->
        "#{name}: #{url}"
      end)

    """
    — Komiuta · Elevate Your Journey
    Website: #{Brand.website()}
    Email: #{Brand.email()} · Call: #{Brand.phone()}
    Follow us: #{social}
    """
  end

  defp paid?(%{status: "success"}), do: true
  defp paid?(_payment), do: false

  defp payment_amount(%{amount: amount, currency: currency}) when is_integer(amount) do
    "#{currency || "KES"} #{format_number(amount)}"
  end

  defp payment_amount(_payment), do: "KES 0"

  defp format_number(amount) do
    amount
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp date(nil), do: "-"

  defp date(%Date{} = date) do
    Calendar.strftime(date, "%d %b %Y")
  end

  defp datetime(nil), do: "-"
  defp datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y, %H:%M")
  defp datetime(%NaiveDateTime{} = datetime), do: Calendar.strftime(datetime, "%d %b %Y, %H:%M")

  defp from_address do
    Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")
  end

  defp logo_url do
    Application.get_env(:xpressbus, :mailer_logo_url) ||
      XpressbusWeb.Endpoint.url() <> "/images/logo_email.png"
  end

  defp recipients, do: AdminAlerts.recipients()

  defp h(nil), do: "-"

  defp h(value),
    do: value |> to_string() |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
