defmodule Mix.Tasks.SmartCityLamp.Demo do
  use Mix.Task

  @shortdoc "Prints the Smart City Lamp dual-browser demo flow"

  @impl true
  def run(["dual_browser"]) do
    Mix.shell().info("""
    Smart City Lamp dual-browser demo

    Interactive map: http://localhost:4000/public-map
    Admin login:     http://localhost:4000/admin/login
    Admin dashboard: http://localhost:4000/admin/dashboard

    Development login:
      email:    admin@smartlamp.local
      password: admin12345

    Open the public map and admin dashboard in separate browsers. Click a lamp
    marker, then run Hit Lamp, Open Cabinet, and Disconnect Power from its drawer.
    """)
  end

  def run(_args) do
    Mix.raise("Usage: mix smart_city_lamp.demo dual_browser")
  end
end
