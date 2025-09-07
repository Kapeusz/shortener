# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :shortnr,
  ecto_repos: [Shortnr.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :shortnr, ShortnrWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ShortnrWeb.ErrorHTML, json: ShortnrWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Shortnr.PubSub,
  live_view: [signing_salt: "5NlSCEhS"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :shortnr, Shortnr.Mailer, adapter: Swoosh.Adapters.Local

# Oban configuration (queues and plugins)
config :shortnr, Oban,
  repo: Shortnr.Repo,
  queues: [default: 10],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # Run daily at 00:00 UTC
       {"0 0 * * *", Shortnr.Workers.ExpireCleanup}
     ]}
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  shortnr: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  shortnr: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Hammer rate-limiting backend (in-memory ETS)
config :hammer,
  backend:
    {Hammer.Backend.ETS,
     [
       expiry_ms: 60_000 * 60 * 4,
       cleanup_interval_ms: 60_000 * 10
     ]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
