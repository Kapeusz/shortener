import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :shortnr, Shortnr.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "shortnr_test#{System.get_env("MIX_TEST_PARTITION")}",
  types: Shortnr.PostgresTypes,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :shortnr, ShortnrWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "8sIHIylByBp1oAJwaAHOl5bqmgAeeMkv+XvJl3ObWRHivfj+RxWrXN5c59PXF7cU",
  server: false

# In test we don't send emails
config :shortnr, Shortnr.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Stable slug secret for deterministic tests
config :shortnr, :slug_secret, "NRdDaHFJrE+5pAKt1y2Ij9eSdxUwLbP/Cn4jH07siWS9qL1qHWJ3ZBkluUDVkZMy"

# Disable geo capture flow in tests so redirects remain 302
config :shortnr, :geo_capture, false

# Disable Oban queues/plugins during tests
config :shortnr, Oban, queues: false, plugins: false
