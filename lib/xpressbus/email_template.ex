defmodule Xpressbus.EmailTemplate do
  @moduledoc """
  The shared KOMIUTA header and footer used by transactional emails.

  Keeping the logo bar, brand strip and contact/social footer here means login
  codes, operational reports and other mail all look like the same product.
  """

  alias Xpressbus.Brand

  @doc """
  Wraps content rows in the branded email shell.

  `content_html` must be one or more `<tr>` rows of the email table. Options:
  `:badge` (right-hand label in the header) and `:preheader` (hidden preview
  text).
  """
  def render(content_html, opts \\ []) do
    badge = Keyword.get(opts, :badge, "KOMIUTA")
    preheader = Keyword.get(opts, :preheader, "")

    """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="light dark" />
        <meta name="supported-color-schemes" content="light dark" />
      </head>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:'Trebuchet MS','Segoe UI',Arial,sans-serif;color:#0f172a;">
        <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:#f8fafc;opacity:0;">
          #{html_escape(preheader)}
        </div>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#f8fafc" style="background:#f8fafc;padding:32px 16px;">
          <tr>
            <td align="center">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border:1px solid #e2e8f0;border-radius:24px;overflow:hidden;">
                <tr>
                  <td bgcolor="#FF4C00" style="background:#FF4C00;height:4px;line-height:4px;font-size:0;">&nbsp;</td>
                </tr>
                <tr>
                  <td bgcolor="#ffffff" style="background:#ffffff;padding:20px 24px 18px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td align="left" valign="middle">
                          <img
                            src="#{logo_url()}"
                            width="146"
                            height="40"
                            alt="KOMIUTA"
                            style="display:block;border:0;outline:none;text-decoration:none;"
                          />
                        </td>
                        <td align="right" valign="middle" style="font-size:10px;font-weight:700;letter-spacing:0.18em;text-transform:uppercase;color:#FF4C00;">
                          #{html_escape(badge)}
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td style="height:1px;line-height:1px;font-size:0;background:#f1f5f9;">&nbsp;</td>
                </tr>
                #{content_html}
                #{footer()}
              </table>
            </td>
          </tr>
        </table>
      </body>
    </html>
    """
  end

  @doc "The shared HTML footer row."
  def footer do
    social_html =
      Brand.social_links()
      |> Enum.map_join(" &nbsp;·&nbsp; ", fn %{name: name, url: url} ->
        ~s(<a href="#{html_escape(url)}" target="_blank" rel="noopener" style="color:#FF4C00;text-decoration:none;">#{html_escape(name)}</a>)
      end)

    """
    <tr>
                  <td align="center" style="padding:20px 28px 24px;border-top:1px solid #f1f5f9;text-align:center;">
                    <p style="margin:0 0 10px;font-size:11px;color:#94a3b8;letter-spacing:0.06em;text-align:center;">
                      KOMIUTA · Elevate Your Journey
                    </p>
                    <p style="margin:0 0 8px;font-size:12px;line-height:1.6;color:#64748b;text-align:center;">
                      <a href="#{html_escape(Brand.website())}" target="_blank" rel="noopener" style="color:#FF4C00;text-decoration:none;">#{html_escape(Brand.website_label())}</a>
                      &nbsp;·&nbsp;
                      <a href="mailto:#{html_escape(Brand.email())}" style="color:#FF4C00;text-decoration:none;">#{html_escape(Brand.email())}</a>
                      &nbsp;·&nbsp;
                      <a href="#{html_escape(Brand.phone_uri())}" style="color:#FF4C00;text-decoration:none;">#{html_escape(Brand.phone())}</a>
                    </p>
                    <p style="margin:0;font-size:11px;line-height:1.6;color:#94a3b8;text-align:center;">
                      Follow us: #{social_html}
                    </p>
                  </td>
                </tr>
    """
  end

  @doc "Plain-text version of the shared footer."
  def text_footer do
    social =
      Enum.map_join(Brand.social_links(), " · ", fn %{name: name, url: url} ->
        "#{name}: #{url}"
      end)

    """
    — KOMIUTA · Elevate Your Journey
    Website: #{Brand.website()}
    Email: #{Brand.email()} · Call: #{Brand.phone()}
    Follow us: #{social}
    """
  end

  @doc "Absolute logo URL used in the header."
  def logo_url do
    Application.get_env(:xpressbus, :mailer_logo_url) ||
      XpressbusWeb.Endpoint.url() <> "/images/logo_email.png"
  end

  @doc "Escape dynamic text inserted into the HTML email."
  def html_escape(text), do: Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()
end
