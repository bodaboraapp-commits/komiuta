defmodule XpressbusWeb.Plugs.GoogleAuthConfig do
  alias Xpressbus.Integrations
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.params["provider"] == "google" do
      config = Integrations.get_config_by_provider("google")

      if config && config.active do
        client_id = String.trim(config.config["client_id"] || "")
        client_secret = String.trim(config.config["client_secret"] || "")

        # Priority: Admin Setting -> construct from conn
        redirect_uri =
          if config.config["redirect_uri"] && config.config["redirect_uri"] != "" do
            String.trim(config.config["redirect_uri"])
          else
            # Construction fallback for local dev / ngrok
            scheme = if conn.host =~ "ngrok", do: "https", else: to_string(conn.scheme)
            port_suffix = if conn.port in [80, 443], do: "", else: ":#{conn.port}"
            "#{scheme}://#{conn.host}#{port_suffix}/auth/google/callback"
          end

        Logger.info("[GOOGLE AUTH] Final Resolved Redirect URI: #{redirect_uri}")

        # Set for Ueberauth Request Phase
        conn =
          Plug.Conn.put_private(conn, :ueberauth_request_options,
            client_id: client_id,
            client_secret: client_secret,
            redirect_uri: redirect_uri,
            callback_url: redirect_uri
          )

        # Set for Ueberauth Callback Phase (Internal strategy verification)
        Application.put_env(:ueberauth, Ueberauth.Strategy.Google.OAuth,
          client_id: client_id,
          client_secret: client_secret,
          redirect_uri: redirect_uri
        )

        conn
      else
        conn
      end
    else
      conn
    end
  end
end
