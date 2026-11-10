defmodule XpressbusWeb.Plugs.EnsureViewport do
  @moduledoc """
  Guarantees every HTML response carries a real mobile viewport.

  Release markers are occasionally written into the layout's viewport tag by
  concurrent release tooling. A viewport such as `2026-11-10...` makes mobile
  browsers fall back to a ~980px desktop layout, so this response-level guard
  corrects the tag even if the template regresses.
  """

  import Plug.Conn

  @viewport ~r/<meta\s+name=["']viewport["']\s+content=["'][^"']*["']\s*\/?>/i
  @mobile_viewport ~s(<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />)

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, &ensure_viewport/1)
  end

  defp ensure_viewport(conn) do
    content_type =
      conn
      |> get_resp_header("content-type")
      |> List.first()
      |> to_string()

    if String.contains?(content_type, "text/html") and is_binary(conn.resp_body) do
      %{conn | resp_body: Regex.replace(@viewport, conn.resp_body, @mobile_viewport)}
    else
      conn
    end
  end
end
