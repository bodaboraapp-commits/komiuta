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

# Configure test database. The defaults match the long-standing local XAMPP
# setup, but every value can be overridden so the suite can run against a
# disposable database (CI, review environments, etc.).
#
# The default database name is deliberately *different* from the development
# database. Points of the suite assert on whole-table results (for example
# `assert Coupons.list_coupons() == [coupon]`), so sharing `buupasskomiuta_db`
# with development data made the suite fail depending on what was seeded
# locally. `mix test` creates and migrates this database automatically.
config :xpressbus, Xpressbus.Repo,
  username: System.get_env("DB_USER", "root"),
  password: System.get_env("DB_PASSWORD", ""),
  database: System.get_env("DB_NAME", "buupasskomiuta_test"),
  hostname: System.get_env("DB_HOST", "127.0.0.1"),
  port: String.to_integer(System.get_env("DB_PORT", "3307")),
  pool: Ecto.Adapters.SQL.Sandbox
