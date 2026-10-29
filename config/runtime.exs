import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/xpressbus start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :xpressbus, XpressbusWeb.Endpoint, server: true
end

config :xpressbus, XpressbusWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :xpressbus, XpressbusWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/xpressbus_web/router\.ex$"E,
        ~r"lib/xpressbus_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      Set it to the public hostname of this deployment, e.g. PHX_HOST=www.komiuta.com
      """

  # --- Database -------------------------------------------------------------
  # Prefer a single DATABASE_URL (same URL style used by most PaaS providers),
  # and fall back to discrete DB_* variables. Production must fail fast when
  # neither is provided instead of starting with an unconfigured Repo.
  # --- Database TLS ---------------------------------------------------------
  # Aiven (and most managed MySQL providers) require an encrypted connection.
  #   DB_SSL=true                 -> TLS, encrypted (verification disabled)
  #   DB_CA_CERT_BASE64=<base64>  -> TLS with full certificate verification
  #                                  (paste `base64 ca.pem`; keeps it one line)
  db_ssl? = System.get_env("DB_SSL", "false") in ["true", "1", "yes"]

  ca_pem =
    cond do
      pem = System.get_env("DB_CA_CERT") ->
        pem

      b64 = System.get_env("DB_CA_CERT_BASE64") ->
        case Base.decode64(b64) do
          {:ok, pem} -> pem
          :error -> nil
        end

      true ->
        nil
    end

  ssl_opts =
    cond do
      not db_ssl? ->
        false

      is_binary(ca_pem) and ca_pem != "" ->
        ca_path = Path.join(System.tmp_dir!(), "komiuta-db-ca.pem")
        File.write!(ca_path, ca_pem)
        [verify: :verify_peer, cacertfile: ca_path]

      true ->
        [verify: :verify_none]
    end

  database_url = System.get_env("DATABASE_URL")

  repo_config =
    if database_url do
      [
        url: database_url,
        pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
        ssl: ssl_opts
      ]
    else
      required = ~w(DB_HOST DB_NAME DB_USER)
      missing = Enum.reject(required, &System.get_env/1)

      if missing != [] do
        raise """
        database configuration is missing.
        Set DATABASE_URL, or all of #{Enum.join(required, ", ")} (plus DB_PASSWORD as needed).
        Missing: #{Enum.join(missing, ", ")}
        """
      end

      [
        hostname: System.get_env("DB_HOST"),
        database: System.get_env("DB_NAME"),
        username: System.get_env("DB_USER"),
        password: System.get_env("DB_PASSWORD", ""),
        port: String.to_integer(System.get_env("DB_PORT", "3306")),
        pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
        ssl: ssl_opts
      ]
    end

  config :xpressbus, Xpressbus.Repo, repo_config

  # Background BuuPass synchronisation is intentionally opt-in. Enable it in
  # production only when this node is the designated sync worker.
  config :xpressbus,
    enable_background_sync: System.get_env("ENABLE_BACKGROUND_SYNC", "false") == "true"

  config :xpressbus, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :xpressbus, XpressbusWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    # Accept same-origin LiveView connections for any hostname (custom domain,
    # onrender.com preview URL, ...). Cross-origin is still rejected.
    check_origin: :conn,
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :xpressbus, XpressbusWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :xpressbus, XpressbusWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :xpressbus, Xpressbus.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
