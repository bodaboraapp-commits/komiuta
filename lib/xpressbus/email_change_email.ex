defmodule Xpressbus.EmailChangeEmail do
  @moduledoc """
  Transactional emails for changing the account email address:

    * a verification code sent to the *new* address
    * a security notice sent to the *old* address
  """

  import Swoosh.Email

  require Logger

  @spec deliver_code(Xpressbus.Accounts.User.t(), String.t(), String.t(), pos_integer()) ::
          :ok | {:error, term()}
  def deliver_code(user, new_email, code, ttl_minutes) do
    user
    |> build_code(new_email, code, ttl_minutes)
    |> Xpressbus.Mailer.deliver()
    |> handle_result("Failed to send email-change code")
  end

  @spec deliver_notice(Xpressbus.Accounts.User.t(), String.t()) :: :ok | {:error, term()}
  def deliver_notice(%{email: email} = user, new_email) when is_binary(email) do
    if String.ends_with?(String.downcase(email), "@xpressbus.com") do
      :ok
    else
      user
      |> build_notice(new_email)
      |> Xpressbus.Mailer.deliver()
      |> handle_result("Failed to send email-change notice")
    end
  end

  def deliver_notice(_user, _new_email), do: :ok

  def build_code(user, new_email, code, ttl_minutes) do
    name = display_name(user)

    new()
    |> to({name, new_email})
    |> from(from())
    |> subject("Confirm your new Komiuta email address")
    |> text_body(code_text(name, code, ttl_minutes))
    |> html_body(code_html(name, code, ttl_minutes))
  end

  def build_notice(%{email: email} = user, new_email) do
    name = display_name(user)

    new()
    |> to({name, email})
    |> from(from())
    |> subject("Email change requested on your Komiuta account")
    |> text_body(notice_text(name, new_email))
    |> html_body(notice_html(name, new_email))
  end

  defp handle_result({:ok, _email}, _message), do: :ok

  defp handle_result({:error, reason}, message) do
    Logger.error(message, reason: inspect(reason))
    {:error, reason}
  end

  defp display_name(user) do
    if is_binary(user.name) and user.name != "", do: user.name, else: "traveller"
  end

  defp from do
    address = Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")
    {"Komiuta", address}
  end

  defp code_text(name, code, ttl_minutes) do
    """
    Hi #{name},

    Your Komiuta email-change code is:

        #{code}

    Enter it in your dashboard to finish changing your email address. It expires
    in #{ttl_minutes} minutes and can only be used once.

    If you did not request this change, ignore this email—your current email
    stays exactly as it is.

    — Komiuta
    """
  end

  defp notice_text(name, new_email) do
    """
    Hi #{name},

    Someone requested to change the email address on your Komiuta account to
    #{new_email}.

    If that was you, no action is needed here—use the code sent to the new
    address to confirm.

    If it was not you, your email has not changed. You can ignore this email,
    but consider updating your login code.

    — Komiuta
    """
  end

  defp code_html(name, code, ttl_minutes) do
    """
    <!DOCTYPE html>
    <html>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:'Trebuchet MS','Segoe UI',Arial,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:32px 16px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border:1px solid #e2e8f0;border-radius:24px;overflow:hidden;">
                <tr>
                  <td style="background:#FF4C00;padding:20px 28px;color:#ffffff;font-size:18px;font-weight:800;">Komiuta</td>
                </tr>
                <tr>
                  <td style="padding:32px 28px 8px;">
                    <p style="margin:0 0 8px;font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#FF4C00;font-weight:800;">Email change</p>
                    <h1 style="margin:0 0 16px;font-size:22px;line-height:1.2;">Hi #{html_escape(name)},</h1>
                    <p style="margin:0 0 24px;font-size:14px;line-height:1.6;color:#475569;">
                      Use the code below to confirm your new Komiuta email address.
                    </p>
                    <div style="background:#fff7ed;border:2px dashed #fdba74;border-radius:16px;padding:20px;text-align:center;margin-bottom:24px;">
                      <div style="font-family:'Courier New',monospace;font-size:34px;letter-spacing:0.35em;font-weight:800;color:#0f172a;">#{code}</div>
                    </div>
                    <p style="margin:0 0 8px;font-size:13px;line-height:1.6;color:#64748b;">
                      It expires in <strong>#{ttl_minutes} minutes</strong> and can only be used once.
                    </p>
                    <p style="margin:0 0 24px;font-size:13px;line-height:1.6;color:#64748b;">
                      If you did not request this change, ignore this email—your current email stays unchanged.
                    </p>
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

  defp notice_html(name, new_email) do
    """
    <!DOCTYPE html>
    <html>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:'Trebuchet MS','Segoe UI',Arial,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:32px 16px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border:1px solid #e2e8f0;border-radius:24px;overflow:hidden;">
                <tr>
                  <td style="background:#FF4C00;padding:20px 28px;color:#ffffff;font-size:18px;font-weight:800;">Komiuta</td>
                </tr>
                <tr>
                  <td style="padding:32px 28px;">
                    <h1 style="margin:0 0 16px;font-size:20px;line-height:1.2;">Email change requested</h1>
                    <p style="margin:0 0 16px;font-size:14px;line-height:1.6;color:#475569;">
                      Hi #{html_escape(name)}, someone requested to change the email on your Komiuta account to
                      <strong>#{html_escape(new_email)}</strong>.
                    </p>
                    <p style="margin:0 0 16px;font-size:13px;line-height:1.6;color:#64748b;">
                      If that was you, use the code sent to the new address to confirm.
                    </p>
                    <p style="margin:0;font-size:13px;line-height:1.6;color:#64748b;">
                      If it was not you, your email has not changed—you can safely ignore this email.
                    </p>
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

  defp html_escape(text), do: Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()
end
