defmodule XpressbusWeb.Plugs.AgentHost do
  @moduledoc """
  Keeps the KOMIUTA Agent PWA on its own origin.

  Chrome/Android treats nested PWA scopes on the same origin as one installed app,
  so the Agent app should be installed from `agent.komiuta.com`, not from
  `www.komiuta.com`. The Agent subdomain root opens the sign-up app.

  The legacy `/agent` path on the website is still served (instead of a
  server-side redirect) so that Agent PWA installs created before the
  subdomain split keep launching in standalone mode — a cross-origin redirect
  during launch makes Android open the browser instead of the app. Browser
  visits to `/agent` on the website are moved to the Agent subdomain
  client-side (see `assets/js/app.js`).
  """

  import Plug.Conn

  @agent_host "agent.komiuta.com"

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.host == @agent_host and conn.request_path == "/" do
      redirect_to(conn, "https://#{@agent_host}/agent")
    else
      conn
    end
  end

  defp redirect_to(conn, url) do
    conn
    |> put_resp_header("location", url)
    |> send_resp(302, "")
    |> halt()
  end
end
