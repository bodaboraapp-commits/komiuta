defmodule XpressbusWeb.Plugs.SeoCacheHeaders do
  @moduledoc """
  Edge/browser caching for the SEO discovery files.

  These are public, non-personal resources, so letting Cloudflare and browsers
  cache them reduces TTFB for crawlers without any risk of caching a logged-in
  page or CSRF token.
  """

  import Plug.Conn

  @paths MapSet.new(["/robots.txt", "/llms.txt", "/sitemap.xml"])

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      if MapSet.member?(@paths, conn.request_path) do
        put_resp_header(
          conn,
          "cache-control",
          "public, max-age=3600, stale-while-revalidate=86400"
        )
      else
        conn
      end
    end)
  end
end
