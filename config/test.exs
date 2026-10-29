import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :xpressbus, XpressbusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "VzCyWxdGFYRgHp3HLv+pkYIEgStycnDgYpG+6O4vBaxPzF2dv6DdAi7UzN9wQS8J",
  server: false

# In test we don't send emails
config :xpressbus, Xpressbus.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Configure test database
config :xpressbus, Xpressbus.Repo,
  username: "root",
  password: "",
  database: "buupasskomiuta_db",
  hostname: "127.0.0.1",
  port: 3307,
  pool: Ecto.Adapters.SQL.Sandbox
