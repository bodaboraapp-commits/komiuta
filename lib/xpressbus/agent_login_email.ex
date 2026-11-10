defmodule Xpressbus.AgentLoginEmail do
  @moduledoc """
  Transactional email delivering a one-time sign-in code to an agent.
  """

  import Swoosh.Email

  require Logger

  alias Xpressbus.Brand
  alias Xpressbus.Agents.AgentApplication

  @spec build(AgentApplication.t(), String.t(), pos_integer()) :: Swoosh.Email.t()
  def build(application, code, ttl_minutes) do
    name = first_name(application.full_name)

    new()
    |> to({application.full_name, application.email})
    |> from(from())
    |> subject("Your KOMIUTA Agent login code")
    |> text_body(text_body(name, code, ttl_minutes))
    |> html_body(html_body(name, code, ttl_minutes))
  end

  @spec deliver(AgentApplication.t(), String.t(), pos_integer()) :: :ok | {:error, term()}
  def deliver(application, code, ttl_minutes) do
    application
    |> build(code, ttl_minutes)
    |> Xpressbus.Mailer.deliver()
    |> case do
      {:ok, _email} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to deliver agent login code email", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp first_name(nil), do: "Agent"

  defp first_name(name) do
    name |> to_string() |> String.split() |> List.first()
  end

  @doc """
  Builds the email that verifies ownership of the email address an agent wants
  on their account.
  """
  def build_verification(application, email, code, ttl_minutes) do
    name = first_name(application.full_name)

    new()
    |> to({application.full_name, email})
    |> from(from())
    |> subject("Verify your email for KOMIUTA Agent")
    |> text_body(verification_text(name, code, ttl_minutes))
    |> html_body(verification_html(name, code, ttl_minutes))
  end

  @doc "Delivers the agent email-verification code."
  def deliver_verification(application, email, code, ttl_minutes) do
    application
    |> build_verification(email, code, ttl_minutes)
    |> Xpressbus.Mailer.deliver()
    |> case do
      {:ok, _email} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to deliver agent email verification", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp verification_text(name, code, ttl_minutes) do
    """
    Hi #{name},

    Use this code to verify the email address on your KOMIUTA Agent account:

        #{code}

    It expires in #{ttl_minutes} minutes and can only be used once.
    If you did not request this, you can ignore this email.

    — KOMIUTA Agent
    Website: #{Brand.website()}
    Email: #{Brand.email()} · Call: #{Brand.phone()}
    """
  end

  defp verification_html(name, code, ttl_minutes) do
    """
    <!doctype html>
    <html>
      <body style="margin:0;padding:0;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f5f7;padding:28px 12px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#ffffff;border-radius:18px;overflow:hidden;">
                <tr>
                  <td style="background:#FF4C00;padding:22px 28px;color:#ffffff;">
                    <div style="font-size:11px;letter-spacing:2px;font-weight:bold;opacity:.9;">KOMIUTA AGENT</div>
                    <div style="font-size:22px;font-weight:800;margin-top:6px;">Verify your email</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding:28px;">
                    <p style="margin:0 0 12px;font-size:14px;line-height:1.6;">Hi #{name},</p>
                    <p style="margin:0 0 18px;font-size:14px;line-height:1.6;">
                      Enter this code in the KOMIUTA Agent app to verify your email address:
                    </p>
                    <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:14px;padding:18px;text-align:center;font-size:32px;letter-spacing:8px;font-weight:800;color:#0f172a;">
                      #{code}
                    </div>
                    <p style="margin:18px 0 0;font-size:12px;line-height:1.6;color:#64748b;">
                      It expires in #{ttl_minutes} minutes and can only be used once.
                      If you did not request this, you can ignore this email.
                    </p>
                  </td>
                </tr>
                <tr>
                  <td style="background:#f8fafc;padding:18px 28px;font-size:11px;line-height:1.7;color:#64748b;text-align:center;">
                    <strong>KOMIUTA Agent</strong><br />
                    #{Brand.website()} · #{Brand.email()} · #{Brand.phone()}
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

  defp from do
    address = Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")
    {"KOMIUTA", address}
  end

  defp verify_url(code) do
    origin = Application.get_env(:xpressbus, :agent_app_origin, "https://agent.komiuta.com")
    "#{String.trim_trailing(origin, "/")}/agent/verify#code=#{URI.encode_www_form(code)}"
  end

  defp text_body(name, code, ttl_minutes) do
    """
    Hi #{name},

    Your KOMIUTA Agent sign-in code is:

        #{code}

    Open this link in the same browser to fill the code automatically:
    #{verify_url(code)}

    It expires in #{ttl_minutes} minutes and can only be used once.
    If you did not try to sign in to the Agent app, you can ignore this email.

    — KOMIUTA Agent
    Website: #{Brand.website()}
    Email: #{Brand.email()} · Call: #{Brand.phone()}
    """
  end

  defp html_body(name, code, ttl_minutes) do
    """
    <!doctype html>
    <html>
      <body style="margin:0;padding:0;background:#f4f5f7;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f5f7;padding:28px 12px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#ffffff;border-radius:18px;overflow:hidden;">
                <tr>
                  <td style="background:#FF4C00;padding:22px 28px;color:#ffffff;">
                    <div style="font-size:11px;letter-spacing:2px;font-weight:bold;opacity:.9;">KOMIUTA AGENT</div>
                    <div style="font-size:22px;font-weight:800;margin-top:6px;">Your sign-in code</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding:28px;">
                    <p style="margin:0 0 12px;font-size:14px;line-height:1.6;">Hi #{name},</p>
                    <p style="margin:0 0 18px;font-size:14px;line-height:1.6;">
                      Use this one-time code to sign in to the KOMIUTA Agent app:
                    </p>
                    <div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:14px;padding:18px;text-align:center;font-size:32px;letter-spacing:8px;font-weight:800;color:#0f172a;">
                      #{code}
                    </div>
                    <p style="margin:18px 0;text-align:center;">
                      <a href="#{verify_url(code)}" style="display:inline-block;background:#FF4C00;color:#ffffff;text-decoration:none;font-size:13px;font-weight:800;padding:13px 22px;border-radius:12px;">
                        Fill code automatically
                      </a>
                    </p>
                    <p style="margin:18px 0 0;font-size:12px;line-height:1.6;color:#64748b;">
                      It expires in #{ttl_minutes} minutes and can only be used once.
                      If you did not try to sign in, you can ignore this email.
                    </p>
                  </td>
                </tr>
                <tr>
                  <td style="background:#f8fafc;padding:18px 28px;font-size:11px;line-height:1.7;color:#64748b;text-align:center;">
                    <strong>KOMIUTA Agent</strong><br />
                    #{Brand.website()} · #{Brand.email()} · #{Brand.phone()}
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
