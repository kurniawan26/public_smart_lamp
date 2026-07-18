import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :smart_city_lamp, SmartCityLamp.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "smart_city_lamp_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :smart_city_lamp, SmartCityLampWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "XzoIMvIIZtBxbFApn33N8Pt5hm76JtFnw6lqlSpdxv9a5FgiMDSW28R/J5VTVw5u",
  server: false

# In test we don't send emails
config :smart_city_lamp, SmartCityLamp.Mailer, adapter: Swoosh.Adapters.Test

config :smart_city_lamp, Oban, testing: :manual, queues: false, plugins: false
config :smart_city_lamp, :live_sensor_interval_ms, false
config :smart_city_lamp, :technician_travel_ms, 30
config :smart_city_lamp, :technician_repair_ms, 30

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
