defmodule XpressbusWeb.Plugs.RequestGuard do
  @moduledoc """
  Rejects malformed or oversized raw requests before they reach the router or
  parameter parsers.

  This is deliberately conservative: it only blocks payloads that are never
  legitimate for this application (NUL bytes in the URI/query string, or an
  absurdly long path/query). Database access remains Ecto-parameterised, so
  this guard is an outer layer rather than a replacement for safe queries.
  """

  @behaviour Plug

  import Plug.Conn

  @max_path_bytes 2_048
  @max_query_bytes 8_192

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    raw_target = conn.request_path <> "?" <> conn.query_string

    cond do
      byte_size(conn.request_path) > @max_path_bytes ->
        reject(conn, 414)

      byte_size(conn.query_string) > @max_query_bytes ->
        reject(conn, 414)

      String.contains?(raw_target, <<0>>) ->
        reject(conn, 400)

      true ->
        conn
    end
  end

  defp reject(conn, status) do
    conn
    |> put_resp_header("content-type", "text/plain; charset=utf-8")
    |> send_resp(status, "Bad Request")
    |> halt()
  end
end
