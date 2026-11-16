defmodule Xpressbus.HotelSyncEmail do
  @moduledoc "Operational report for the two-day Google hotel refresh."

  import Swoosh.Email
  require Logger

  alias Xpressbus.{EmailTemplate, Mailer}

  @default_recipient "komondiedward@gmail.com"

  def recipient do
    case Application.get_env(:xpressbus, :hotel_sync_alert_email) do
      value when is_binary(value) and value != "" -> String.trim(value)
      _other -> @default_recipient
    end
  end

  def build(run) do
    new()
    |> to(recipient())
    |> from({"Komiuta", Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")})
    |> subject(
      "Chyllz Google hotel sync: #{run.status} (#{run.matched_count}/#{run.hotels_count})"
    )
    |> text_body(body(run))
    |> html_body(html(run))
  end

  def deliver(run) do
    if Application.get_env(:xpressbus, :hotel_sync_notifications, true) do
      case Mailer.deliver(build(run)) do
        {:ok, _result} = ok ->
          Logger.info("Google hotel sync report emailed to #{recipient()}")
          ok

        {:error, reason} = error ->
          Logger.warning("Could not email Google hotel sync report: #{inspect(reason)}")
          error
      end
    else
      :skipped
    end
  rescue
    error ->
      Logger.warning("Could not email Google hotel sync report: #{inspect(error)}")
      {:error, error}
  end

  defp body(run) do
    """
    Chyllz Google hotel sync

    Status: #{run.status}
    Hotels checked: #{run.hotels_count}
    Matched on Google: #{run.matched_count}
    Run at: #{run.inserted_at || DateTime.utc_now()} UTC

    Details:
    #{run.details || "—"}

    #{EmailTemplate.text_footer()}
    """
  end

  defp html(run) do
    details =
      (run.details || "")
      |> String.split("\n", trim: true)
      |> Enum.map_join("", fn line ->
        ~s(<li style="margin:0 0 8px;font-size:13px;line-height:1.6;color:#475569;">#{EmailTemplate.html_escape(line)}</li>)
      end)

    status_color =
      case run.status do
        "success" -> "#059669"
        "partial" -> "#d97706"
        _ -> "#dc2626"
      end

    content = """
    <tr>
      <td style="padding:32px 28px 8px;">
        <p style="margin:0 0 8px;font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#FF4C00;font-weight:800;">Operations report</p>
        <h1 style="margin:0 0 16px;font-size:22px;line-height:1.2;">Google hotel sync</h1>
        <p style="margin:0 0 20px;font-size:14px;line-height:1.6;color:#475569;">
          Status: <strong style="color:#{status_color};">#{EmailTemplate.html_escape(run.status)}</strong><br />
          Hotels checked: <strong>#{run.hotels_count}</strong><br />
          Matched on Google: <strong>#{run.matched_count}</strong>
        </p>
        <ul style="margin:0 0 20px;padding-left:18px;">#{details}</ul>
        <p style="margin:0 0 24px;font-size:11px;line-height:1.6;color:#94a3b8;">
          Run at #{run.inserted_at || DateTime.utc_now()} UTC
        </p>
      </td>
    </tr>
    """

    EmailTemplate.render(content,
      badge: "Hotel sync report",
      preheader: "Google hotel sync #{run.status}: #{run.matched_count}/#{run.hotels_count} hotels matched."
    )
  end

end
