defmodule Xpressbus.AgentApplicationEmail do
  @moduledoc """
  Transactional emails for agent applications submitted from the Komiuta Agent PWA.
  """

  import Swoosh.Email

  alias Xpressbus.Mailer

  def deliver_applicant(application) do
    new()
    |> to({application.full_name, application.email})
    |> from({"Komiuta Agent", from_address()})
    |> subject("We received your Komiuta Agent application (#{application.reference})")
    |> text_body("""
    Hi #{first_name(application.full_name)},

    Thank you for applying to become a Komiuta Agent.

    Your application reference is #{application.reference}. Our partnerships team will review
    your details and contact you on #{application.phone} or #{application.email}.

    What happens next:
    1. We review your business and routes.
    2. We contact you to complete verification.
    3. Once approved, you can start selling Komiuta tickets from the Agent app.

    If you have any questions, reply to this email or call 0800 211 211.

    The Komiuta Agent team
    """)
    |> html_body("""
    <!DOCTYPE html>
    <html lang="en">
      <body style="margin:0;background:#f8fafc;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:24px 12px;">
          <tr><td align="center">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#fff;border:1px solid #e2e8f0;border-radius:24px;overflow:hidden;">
              <tr><td style="background:#FF4C00;height:6px;font-size:0;">&nbsp;</td></tr>
              <tr><td style="padding:28px 32px 0;"><img src="#{XpressbusWeb.Endpoint.url()}/images/logo_email.png" alt="Komiuta" width="146" height="40" style="display:block;border:0;" /></td></tr>
              <tr><td style="padding:24px 32px 8px;">
                <p style="margin:0 0 8px;font-size:11px;font-weight:800;letter-spacing:2px;text-transform:uppercase;color:#FF4C00;">Agent application</p>
                <h1 style="margin:0;font-size:26px;color:#0f172a;">Thanks, #{first_name(application.full_name)}.</h1>
                <p style="margin:14px 0 0;font-size:15px;line-height:1.7;color:#475569;">We received your application to become a Komiuta Agent. Our partnerships team will review your details and contact you shortly.</p>
              </td></tr>
              <tr><td style="padding:20px 32px;">
                <table role="presentation" width="100%" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:16px;"><tr><td style="padding:18px 20px;">
                  <p style="margin:0;font-size:11px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase;color:#94a3b8;">Your reference</p>
                  <p style="margin:6px 0 0;font-size:24px;font-weight:800;color:#0f172a;">#{application.reference}</p>
                  <p style="margin:8px 0 0;font-size:13px;color:#64748b;">#{application.business_name} · #{application.city}</p>
                </td></tr></table>
              </td></tr>
              <tr><td style="padding:0 32px 24px;"><p style="margin:0;font-size:14px;line-height:1.7;color:#475569;">Questions? Reply to this email or call <strong>0800 211 211</strong>.</p><p style="margin:18px 0 0;font-size:14px;color:#64748b;">The Komiuta Agent team</p></td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
    """)
    |> Mailer.deliver()
  end

  def deliver_admin(application) do
    new()
    |> to({"Komiuta Partnerships", Xpressbus.Brand.email()})
    |> from({"Komiuta Agent", from_address()})
    |> subject("New Komiuta Agent application — #{application.business_name}")
    |> text_body("""
    A new agent application was submitted.

    Reference: #{application.reference}
    Name: #{application.full_name}
    Business: #{application.business_name}
    City: #{application.city}
    Phone: #{application.phone}
    Email: #{application.email}
    Payout: #{application.payout_method}
    Routes: #{application.routes || "-"}
    Notes: #{application.notes || "-"}

    Review it at /admin/agent-applications.
    """)
    |> Mailer.deliver()
  end

  @doc """
  Sends an agent a lifecycle update: pending review, approved or rejected.
  """
  def deliver_status(application, event, reason \\ nil) do
    {subject, heading, message} = status_content(application, event, reason)
    login_url = agent_login_url()

    new()
    |> to({application.full_name, application.email})
    |> from({"Komiuta Agent", from_address()})
    |> subject(subject)
    |> text_body("""
    Hi #{first_name(application.full_name)},

    #{message}

    Agent reference: #{application.reference}
    Business: #{application.business_name}
    #{if reason && String.trim(to_string(reason)) != "", do: "Reason: #{reason}\n", else: ""}
    You can log in to track your application at #{login_url}

    Need help? Reply to this email or call 0800 211 211.

    The Komiuta Agent team
    """)
    |> html_body("""
    <!DOCTYPE html>
    <html lang="en">
      <body style="margin:0;background:#f8fafc;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:24px 12px;">
          <tr><td align="center">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#fff;border:1px solid #e2e8f0;border-radius:24px;overflow:hidden;">
              <tr><td style="background:#FF4C00;height:6px;font-size:0;">&nbsp;</td></tr>
              <tr><td style="padding:28px 32px 0;"><img src="#{XpressbusWeb.Endpoint.url()}/images/logo_email.png" alt="Komiuta" width="146" height="40" style="display:block;border:0;" /></td></tr>
              <tr><td style="padding:24px 32px 8px;">
                <p style="margin:0 0 8px;font-size:11px;font-weight:800;letter-spacing:2px;text-transform:uppercase;color:#FF4C00;">Agent application update</p>
                <h1 style="margin:0;font-size:26px;color:#0f172a;">#{html_escape(heading)}</h1>
                <p style="margin:14px 0 0;font-size:15px;line-height:1.7;color:#475569;">#{html_escape(message)}</p>
              </td></tr>
              <tr><td style="padding:20px 32px;">
                <table role="presentation" width="100%" style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:16px;"><tr><td style="padding:18px 20px;">
                  <p style="margin:0;font-size:11px;font-weight:800;letter-spacing:1.5px;text-transform:uppercase;color:#94a3b8;">Your reference</p>
                  <p style="margin:6px 0 0;font-size:24px;font-weight:800;color:#0f172a;">#{application.reference}</p>
                  <p style="margin:8px 0 0;font-size:13px;color:#64748b;">#{html_escape(application.business_name)}</p>
                </td></tr></table>
              </td></tr>
              #{if reason && String.trim(to_string(reason)) != "", do: "<tr><td style=\"padding:0 32px 8px;\"><p style=\"margin:0;font-size:14px;line-height:1.7;color:#475569;\"><strong>Reason:</strong> #{html_escape(reason)}</p></td></tr>", else: ""}
              <tr><td style="padding:0 32px 24px;"><p style="margin:0;font-size:14px;line-height:1.7;color:#475569;">Track your application by logging in at <a href="#{login_url}" style="color:#FF4C00;font-weight:700;">#{login_url}</a>.</p><p style="margin:18px 0 0;font-size:14px;color:#64748b;">The Komiuta Agent team</p></td></tr>
            </table>
          </td></tr>
        </table>
      </body>
    </html>
    """)
    |> Mailer.deliver()
  end

  defp status_content(application, :pending, reason) do
    {"Your Komiuta Agent application is still pending", "Application pending",
     "Your application for #{application.business_name} is still under review. We will update you as soon as the review is complete.#{note_suffix(reason)}"}
  end

  defp status_content(application, :approved, _reason) do
    {"Your Komiuta Agent application is approved", "You're approved!",
     "Great news — your application for #{application.business_name} has been approved. Our partnerships team will contact you about activation and selling on Komiuta."}
  end

  defp status_content(application, :rejected, reason) do
    {"Update on your Komiuta Agent application", "Application update",
     "Unfortunately, your application for #{application.business_name} was not approved.#{reason_suffix(reason)} Contact us on 0800 211 211 if you would like to discuss this."}
  end

  defp status_content(application, _event, _reason) do
    {"Update on your Komiuta Agent application", "Application update",
     "Your application for #{application.business_name} has been updated. Log in to see the latest status."}
  end

  defp reason_suffix(reason) do
    case reason && String.trim(to_string(reason)) do
      "" -> ""
      nil -> ""
      value -> " Reason: #{value}"
    end
  end

  defp note_suffix(reason), do: reason_suffix(reason)

  defp agent_login_url do
    Application.get_env(:xpressbus, :agent_app_url, "https://agent.komiuta.com") <>
      "/agent/login"
  end

  defp html_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp from_address do
    Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")
  end

  defp first_name(nil), do: "there"
  defp first_name(name), do: name |> to_string() |> String.split() |> List.first()
end
