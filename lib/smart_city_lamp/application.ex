defmodule SmartCityLamp.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SmartCityLampWeb.Telemetry,
      SmartCityLamp.Repo,
      {Oban, Application.fetch_env!(:smart_city_lamp, Oban)},
      {DNSCluster, query: Application.get_env(:smart_city_lamp, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SmartCityLamp.PubSub},
      SmartCityLamp.Simulations.RateLimiter,
      SmartCityLamp.Simulations.LiveSensorBroadcaster,
      # Start a worker by calling: SmartCityLamp.Worker.start_link(arg)
      # {SmartCityLamp.Worker, arg},
      # Start to serve requests, typically the last entry
      SmartCityLampWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SmartCityLamp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SmartCityLampWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
