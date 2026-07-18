defmodule SmartCityLampWeb.Router do
  use SmartCityLampWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SmartCityLampWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SmartCityLampWeb.Plugs.EnsureSimulatorSession
    plug SmartCityLampWeb.Plugs.FetchCurrentAdmin
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_authenticated_admin do
    plug SmartCityLampWeb.Plugs.RequireAuthenticatedAdmin
  end

  pipeline :redirect_if_admin_authenticated do
    plug SmartCityLampWeb.Plugs.RedirectIfAdminAuthenticated
  end

  pipeline :require_public_emulator do
    plug SmartCityLampWeb.Plugs.RequirePublicEmulator
  end

  scope "/", SmartCityLampWeb do
    pipe_through :browser

    live "/", Public.HomeLive, :index
    live "/public-map", Public.MapLive, :index
    live "/about", Public.AboutLive, :index
  end

  scope "/admin", SmartCityLampWeb do
    pipe_through [:browser, :redirect_if_admin_authenticated]

    get "/login", Admin.SessionController, :new
    post "/login", Admin.SessionController, :create
  end

  scope "/admin", SmartCityLampWeb do
    pipe_through :browser
    delete "/logout", Admin.SessionController, :delete
  end

  scope "/admin", SmartCityLampWeb do
    pipe_through [:browser, :require_authenticated_admin]

    live_session :authenticated_admin,
      on_mount: [{SmartCityLampWeb.AdminAuth, :ensure_authenticated}] do
      live "/", MonitoringLive, :index
      live "/dashboard", MonitoringLive, :index
      live "/devices", Admin.SectionLive, :devices
      live "/devices/:id", DeviceDetailLive, :show
      live "/incidents", Admin.SectionLive, :incidents
      live "/incidents/:id", Admin.SectionLive, :incident
      live "/commands", Admin.SectionLive, :commands
      live "/settings", Admin.SectionLive, :settings
      live "/simulator-controls", Admin.SectionLive, :simulator_controls
    end
  end

  scope "/api", SmartCityLampWeb do
    pipe_through :api
    post "/telemetry", TelemetryController, :create
  end

  scope "/api", SmartCityLampWeb do
    pipe_through [:api, :require_public_emulator]
    post "/simulator/events", Api.SimulatorEventController, :create
  end

  if Application.compile_env(:smart_city_lamp, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: SmartCityLampWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
