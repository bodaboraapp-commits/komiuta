defmodule Xpressbus.LoginEmail do
  @moduledoc """
  The transactional email that delivers a one-time login code.

  The email deliberately contains only the code and a short expiry notice — no
  account details, ticket data or links that expire.
  """

  import Swoosh.Email

  require Logger

  alias Xpressbus.EmailTemplate

  @spec build(Xpressbus.Accounts.User.t(), String.t(), pos_integer()) :: Swoosh.Email.t()
  def build(user, code, ttl_minutes) do
    name = if is_binary(user.name) and user.name != "", do: user.name, else: "traveller"

    new()
    |> to({name, user.email})
    |> from(from())
    |> subject("Your KOMIUTA login code")
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
    {"KOMIUTA", address}
  end

  defp verify_url(code) do
    "#{XpressbusWeb.Endpoint.url()}/user/verify#code=#{URI.encode_www_form(code)}"
  end

  defp text_body(name, code, ttl_minutes) do
    """
    Hi #{name},

    Your KOMIUTA login code is:

        #{code}

    Open this link in the same browser to fill the code automatically:
    #{verify_url(code)}

    It expires in #{ttl_minutes} minutes and can only be used once.
    If you did not try to sign in, you can ignore this email — no one can log
    in without this code.

    #{text_footer()}
    """
  end

  defp text_footer, do: EmailTemplate.text_footer()

  defp html_body(name, code, ttl_minutes) do
    content = """
    <tr>
      <td style="padding:32px 28px 8px;">
        <p style="margin:0 0 8px;font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#FF4C00;font-weight:800;">Login code</p>
        <h1 style="margin:0 0 16px;font-size:22px;line-height:1.2;">Hi #{EmailTemplate.html_escape(name)},</h1>
        <p style="margin:0 0 24px;font-size:14px;line-height:1.6;color:#475569;">
          Use the code below to sign in to your KOMIUTA account.
        </p>
        <div style="background:#fff7ed;border:2px dashed #fdba74;border-radius:16px;padding:20px;text-align:center;margin-bottom:16px;">
          <div style="font-family:'Courier New',monospace;font-size:34px;letter-spacing:0.35em;font-weight:800;color:#0f172a;">#{code}</div>
        </div>
        <p style="margin:0 0 20px;text-align:center;">
          <a href="#{verify_url(code)}" style="display:inline-block;background:#FF4C00;color:#ffffff;text-decoration:none;font-size:13px;font-weight:800;padding:13px 22px;border-radius:12px;">
            Fill code automatically
          </a>
        </p>
        <p style="margin:0 0 8px;font-size:13px;line-height:1.6;color:#64748b;">
          This code expires in <strong>#{ttl_minutes} minutes</strong> and can only be used once.
        </p>
        <p style="margin:0 0 24px;font-size:13px;line-height:1.6;color:#64748b;">
          If you did not try to sign in, you can ignore this email — no one can log in without this code.
        </p>
      </td>
    </tr>
    """

    EmailTemplate.render(content,
      badge: "Secure sign-in",
      preheader: "Your KOMIUTA login code expires in #{ttl_minutes} minutes."
    )
  end
end
