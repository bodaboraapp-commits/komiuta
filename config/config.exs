import Config

config :xpressbus,
  ecto_repos: [Xpressbus.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :xpressbus, XpressbusWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: XpressbusWeb.ErrorHTML, json: XpressbusWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Xpressbus.PubSub,
  live_view: [signing_salt: "k4dYQZ9q"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r",
  colocated_assets: [disable_symlink_warning: true]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :xpressbus, Xpressbus.Mailer, adapter: Swoosh.Adapters.Local

# From-address used for transactional email (login codes). Override in
# production with the MAILER_FROM environment variable.
config :xpressbus, :mailer_from, "no-reply@komiuta.com"

# Public contact details and social links, used by the website footer and
# transactional email. Update the social URLs here when the real handles change.
config :xpressbus, :brand, %{
  website: "https://www.komiuta.com",
  email: "hello@komiuta.com",
  phone: "0800 211 211",
  phone_uri: "tel:0800211211",
  social_links: [
    %{name: "Facebook", url: "https://www.facebook.com/komiuta"},
    %{name: "Instagram", url: "https://www.instagram.com/komiuta"},
    %{name: "X", url: "https://x.com/komiuta"},
    %{name: "TikTok", url: "https://www.tiktok.com/@komiuta"}
  ]
}

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  xpressbus: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  xpressbus: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
