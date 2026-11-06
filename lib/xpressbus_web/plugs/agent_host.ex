defmodule XpressbusWeb.Plugs.AgentHost do
  @moduledoc """
  Keeps the KOMIUTA Agent PWA on its own origin.

  Chrome/Android treats nested PWA scopes on the same origin as one installed app,
  so the Agent app must not be installed from `www.komiuta.com`. The Agent PWA
  lives on `agent.komiuta.com`; the legacy `/agent` URL on the website redirects
  there, and the Agent subdomain root opens the sign-up app.
  """

  import Plug.Conn

  @agent_host "agent.komiuta.com"
  @website_hosts ["komiuta.com", "www.komiuta.com"]

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      conn.host == @agent_host and conn.request_path == "/" ->
        redirect_to(conn, "https://#{@agent_host}/agent")

      conn.host in @website_hosts and conn.request_path == "/agent" ->
        redirect_to(conn, "https://#{@agent_host}/agent")

      true ->
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
