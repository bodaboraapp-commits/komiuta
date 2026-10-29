import Config

# Configure your database
config :xpressbus, Xpressbus.Repo,
  username: "root",
  password: "",
  hostname: "127.0.0.1",
  port: 3307,
  database: "buupasskomiuta_db",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 30,
  queue_target: 5000,
  queue_interval: 10000,
  idle_interval: 30_000,
  connection_lifetime: {30, :second}

# For development, we disable any cache and enable
# debugging and code reloading.
config :xpressbus, XpressbusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "yPR8zh0IhOJG7RY+5tnSxbpo1+xtC1hIUMtea1cYcYTl4SfsiSWfZgmarc67HDeR",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:xpressbus, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:xpressbus, ~w(--watch)]}
  ]

# Enable dev routes for dashboard and mailbox
config :xpressbus, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

# Enable background sync to keep database in sync with buupass.com
config :xpressbus, enable_background_sync: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
