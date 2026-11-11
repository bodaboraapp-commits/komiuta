defmodule XpressbusWeb.ErrorMonitoring do
  @moduledoc """
  Production 500 monitoring for critical LiveView and browser routes.

  Phoenix emits `[:phoenix, :endpoint, :stop]` after a request is rendered,
  including the response status and request id. We attach one telemetry handler
  for that event, ignore successful responses and alert the operations inbox
  whenever a critical route ends in a 5xx.

  Alerts are rate-limited per route so one broken deploy cannot flood the
  inbox. The alert includes the route, HTTP method, status, request id and
  query string; no cookies, headers, form body or personal data are included.
  """

  use GenServer

  require Logger

  alias Xpressbus.AdminAlerts

  @handler_id "komiuta-web-error-monitor"
  @cooldown_ms :timer.minutes(5)
  @critical_prefixes [
    "/",
    "/buses",
    "/dashboard",
    "/trip",
    "/tour-packages",
    "/checkout",
    "/payments",
    "/review-and-pay",
    "/passenger-details",
    "/payment-processing",
    "/tickets",
    "/agent",
    "/admin"
  ]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    :telemetry.detach(@handler_id)

    :telemetry.attach(
      @handler_id,
      [:phoenix, :endpoint, :stop],
      &__MODULE__.handle_event/4,
      self()
    )

    {:ok, %{last_alert: %{}}}
  end

  @doc false
  def handle_event(_event, measurements, metadata, pid) do
    conn = metadata[:conn]

    if conn && is_integer(conn.status) && conn.status >= 500 && critical?(conn.request_path) do
      details = %{
        path: conn.request_path,
        method: conn.method,
        status: conn.status,
        request_id: request_id(conn),
        query_string: conn.query_string,
        duration_ms: duration_ms(measurements)
      }

      GenServer.cast(pid, {:web_error, details})
    end

    :ok
  end

  @impl true
  def handle_cast({:web_error, details}, state) do
    now = System.monotonic_time(:millisecond)
    previous = Map.get(state.last_alert, details.path, 0)

    state =
      if now - previous >= @cooldown_ms do
        Logger.error("Production web error: #{format(details)}")
        AdminAlerts.error_alert(details)
        put_in(state.last_alert[details.path], now)
      else
        state
      end

    {:noreply, state}
  end

  defp request_id(conn) do
    conn.assigns[:request_id] ||
      case Plug.Conn.get_resp_header(conn, "x-request-id") do
        [id | _rest] -> id
        _other -> nil
      end
  end

  defp duration_ms(%{duration: duration}) when is_integer(duration) do
    System.convert_time_unit(duration, :native, :millisecond)
  end

  defp duration_ms(_measurements), do: nil

  defp critical?(path) when is_binary(path) do
    Enum.any?(@critical_prefixes, fn
      "/" -> path == "/"
      prefix -> path == prefix or String.starts_with?(path, prefix <> "/")
    end)
  end

  defp critical?(_path), do: false

  @doc false
  def format(details) do
    "path=#{details.path} method=#{details.method} status=#{details.status} " <>
      "request_id=#{details.request_id || "unknown"}"
  end
end
