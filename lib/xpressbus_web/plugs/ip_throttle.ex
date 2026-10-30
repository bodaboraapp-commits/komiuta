defmodule XpressbusWeb.Plugs.IpThrottle do
  @moduledoc """
  Per-IP fixed-window rate limiting for sensitive auth endpoints.

  Counters live in a public ETS table owned by
  `XpressbusWeb.Plugs.IpThrottleStore` (started in the application supervision
  tree). Each bucket is keyed by `{bucket, client_ip}` so `/user/auth` and
  `/user/verify` have independent budgets.

  When the limit is exceeded the request is redirected back to the login page
  with an explanatory flash and a `retry-after` header.
  """

  @behaviour Plug

  import Plug.Conn

  @table :xpressbus_ip_throttle

  @impl true
  def init(opts) do
    %{
      bucket: Keyword.fetch!(opts, :bucket),
      limit: Keyword.get(opts, :limit, 10),
      window: Keyword.get(opts, :window, 600),
      message:
        Keyword.get(
          opts,
          :message,
          "Too many attempts from your network. Please wait a few minutes and try again."
        )
    }
  end

  @impl true
  def call(conn, %{bucket: bucket, limit: limit, window: window, message: message}) do
    case allow?(bucket, client_ip(conn), limit, window) do
      {:ok, _count} ->
        conn

      {:error, retry_after} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> maybe_put_flash(message)
        |> Phoenix.Controller.redirect(to: "/user/login")
        |> halt()
    end
  end

  @doc """
  Counts one request for `{bucket, ip}`. Public so LiveViews can throttle
  in-socket events (e.g. ticket lookups) with the same store.

  Returns `{:ok, count}` or `{:error, retry_after_seconds}`.
  """
  def allow?(bucket, ip, limit, window) do
    ensure_table()
    now = System.system_time(:second)
    window_start = div(now, window) * window
    count = bump({bucket, ip}, window_start)

    if count > limit do
      {:error, max(window_start + window - now, 1)}
    else
      {:ok, count}
    end
  end

  @doc "Clears all counters. Used by tests."
  def reset do
    ensure_table()
    :ets.delete_all_objects(@table)
    :ok
  end

  # Flash may not be fetched when the plug is used outside the browser
  # pipeline (e.g. in isolated plug tests).
  defp maybe_put_flash(conn, message) do
    if Map.has_key?(conn.assigns, :flash) do
      Phoenix.Controller.put_flash(conn, :error, message)
    else
      conn
    end
  end

  defp bump(key, window_start) do
    case :ets.lookup(@table, key) do
      [{^key, ^window_start, count}] ->
        next = count + 1
        :ets.insert(@table, {key, window_start, next})
        next

      _ ->
        :ets.insert(@table, {key, window_start, 1})
        1
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [
            :named_table,
            :public,
            :set,
            read_concurrency: true,
            write_concurrency: true
          ])
        rescue
          ArgumentError -> @table
        end

      _reference ->
        @table
    end
  end

  # Render terminates TLS in front of the app, so the real client address is in
  # X-Forwarded-For. Locally (and in tests) there is no header.
  defp client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      _ ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
