defmodule Xpressbus.LoginEmail do
  @moduledoc """
  The transactional email that delivers a one-time login code.

  The email deliberately contains only the code and a short expiry notice — no
  account details, ticket data or links that expire.
  """

  import Swoosh.Email

  require Logger

  @spec build(Xpressbus.Accounts.User.t(), String.t(), pos_integer()) :: Swoosh.Email.t()
  def build(user, code, ttl_minutes) do
    name = if is_binary(user.name) and user.name != "", do: user.name, else: "traveller"

    new()
    |> to({name, user.email})
    |> from(from())
    |> subject("Your Komiuta login code")
    |> text_body(text_body(name, code, ttl_minutes))
    |> html_body(html_body(name, code, ttl_minutes))
  end

  @doc """
  Delivers the login code email through the configured Swoosh adapter.
  """
  @spec deliver(Xpressbus.Accounts.User.t(), String.t(), pos_integer()) ::
          :ok | {:error, term()}
  def deliver(user, code, ttl_minutes) do
    user
    |> build(code, ttl_minutes)
    |> Xpressbus.Mailer.deliver()
    |> case do
      {:ok, _email} ->
        :ok

      {:error, reason} ->
        Logger.error("Failed to deliver login code email", reason: inspect(reason))
        {:error, reason}
    end
  end

  defp from do
    address = Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")
    {"Komiuta", address}
  end

  defp text_body(name, code, ttl_minutes) do
    """
    Hi #{name},

    Your Komiuta login code is:

        #{code}

    It expires in #{ttl_minutes} minutes and can only be used once.
    If you did not try to sign in, you can ignore this email — no one can log
    in without this code.

    — Komiuta
    """
  end

  defp html_body(name, code, ttl_minutes) do
    """
    <!DOCTYPE html>
    <html>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:'Trebuchet MS','Segoe UI',Arial,sans-serif;color:#0f172a;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:32px 16px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border:1px solid #e2e8f0;border-radius:24px;overflow:hidden;">
                <tr>
                  <td style="background:#FF4C00;padding:20px 28px;color:#ffffff;font-size:18px;font-weight:800;">
                    Komiuta
                  </td>
                </tr>
                <tr>
                  <td style="padding:32px 28px 8px;">
                    <p style="margin:0 0 8px;font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#FF4C00;font-weight:800;">Login code</p>
                    <h1 style="margin:0 0 16px;font-size:22px;line-height:1.2;">Hi #{html_escape(name)},</h1>
                    <p style="margin:0 0 24px;font-size:14px;line-height:1.6;color:#475569;">
                      Use the code below to sign in to your Komiuta account.
                    </p>
                    <div style="background:#fff7ed;border:2px dashed #fdba74;border-radius:16px;padding:20px;text-align:center;margin-bottom:24px;">
                      <div style="font-family:'Courier New',monospace;font-size:34px;letter-spacing:0.35em;font-weight:800;color:#0f172a;">#{code}</div>
                    </div>
                    <p style="margin:0 0 8px;font-size:13px;line-height:1.6;color:#64748b;">
                      This code expires in <strong>#{ttl_minutes} minutes</strong> and can only be used once.
                    </p>
                    <p style="margin:0 0 24px;font-size:13px;line-height:1.6;color:#64748b;">
                      If you did not try to sign in, you can ignore this email — no one can log in without this code.
                    </p>
                  </td>
                </tr>
                <tr>
                  <td style="padding:16px 28px 28px;border-top:1px solid #f1f5f9;">
                    <p style="margin:0;font-size:11px;color:#94a3b8;letter-spacing:0.06em;">
                      Komiuta · Elevate Your Journey
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
