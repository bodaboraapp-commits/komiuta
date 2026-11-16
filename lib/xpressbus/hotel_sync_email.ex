defmodule Xpressbus.HotelSyncEmail do
  @moduledoc "Operational report for the two-day Google hotel refresh."

  import Swoosh.Email
  require Logger

  alias Xpressbus.Mailer

  @default_recipient "komondiedward@gmail.com"

  def recipient do
    Application.get_env(:xpressbus, :hotel_sync_alert_email, @default_recipient)
  end

  def build(run) do
    new()
    |> to(recipient())
    |> from({"Komiuta", Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")})
    |> subject("Chyllz Google hotel sync: #{run.status} (#{run.matched_count}/#{run.hotels_count})")
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
    """
  end

  defp html(run) do
    details =
      (run.details || "")
      |> String.split("\n", trim: true)
      |> Enum.map_join("", fn line -> "<li>#{line}</li>" end)

    """
    <h2>Chyllz Google hotel sync</h2>
    <p><strong>Status:</strong> #{run.status}<br/>
    <strong>Hotels checked:</strong> #{run.hotels_count}<br/>
    <strong>Matched on Google:</strong> #{run.matched_count}</p>
    <ul>#{details}</ul>
    <p style="color:#64748b;font-size:12px">This report was generated automatically by KOMIUTA.</p>
    """
  end
end
