# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :smart_city_lamp,
  ecto_repos: [SmartCityLamp.Repo],
  generators: [timestamp_type: :utc_datetime],
  enable_public_emulator: true,
  live_sensor_interval_ms: 3_000,
  technician_travel_ms: 15_000,
  technician_repair_ms: 8_000

# Configure the endpoint
config :smart_city_lamp, SmartCityLampWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SmartCityLampWeb.ErrorHTML, json: SmartCityLampWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SmartCityLamp.PubSub,
  live_view: [signing_salt: "4+F0Jo9K"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :smart_city_lamp, SmartCityLamp.Mailer, adapter: Swoosh.Adapters.Local

config :smart_city_lamp, Oban,
  repo: SmartCityLamp.Repo,
  queues: [monitoring: 5, repairs: 1],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", SmartCityLamp.Workers.HeartbeatWorker}
     ]}
  ]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  smart_city_lamp: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  smart_city_lamp: [
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

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
