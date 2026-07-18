defmodule SmartCityLampWeb.RealtimeEmulatorDashboardTest do
  use SmartCityLampWeb.ConnCase
  use Oban.Testing, repo: SmartCityLamp.Repo

  import Phoenix.LiveViewTest

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Simulations.RateLimiter
  alias SmartCityLamp.Simulations.LiveSensorBroadcaster

  test "public HIT_LAMP is reflected on the authenticated dashboard without reload", %{conn: conn} do
    RateLimiter.reset()

    device =
      Repo.insert!(%Device{
        device_code: "LAMP-DUAL-001",
        name: "Dual Browser Lamp",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Dual Browser Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    admin = create_admin()

    {:ok, dashboard, _html} = live(log_in_admin(conn, admin), ~p"/admin/dashboard")
    {:ok, public_map, _html} = live(recycle(conn), ~p"/public-map")

    render_hook(public_map, "select_device", %{"id" => device.id})
    public_map |> element("#scenario-hit_lamp") |> render_click()

    assert has_element?(public_map, "#last-simulation-result", "warning")
    assert has_element?(dashboard, "#recent-telemetry article")
    assert Repo.reload!(device).security_status == :warning
  end

  test "public user cannot access incident or device administration", %{conn: conn} do
    assert redirected_to(get(conn, ~p"/admin/incidents")) == ~p"/admin/login"
    assert redirected_to(get(recycle(conn), ~p"/admin/devices")) == ~p"/admin/login"
  end

  test "random ambient reading reaches public drawer and admin through websocket", %{conn: conn} do
    device =
      Repo.insert!(%Device{
        device_code: "LAMP-LIVE-DUAL-001",
        name: "Live Dual Lamp",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Live Dual Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    admin = create_admin()
    {:ok, dashboard, _html} = live(log_in_admin(conn, admin), ~p"/admin/dashboard")
    {:ok, public_map, _html} = live(recycle(conn), ~p"/public-map")
    render_hook(public_map, "select_device", %{"id" => device.id})

    assert :ok = LiveSensorBroadcaster.broadcast_device(device)
    assert has_element?(public_map, "#live-environment-feed", "WebSocket only")
    assert has_element?(dashboard, "#admin-live-sensors article")
  end

  test "admin dispatches from the large map and public map receives the repair route", %{
    conn: conn
  } do
    device =
      Repo.insert!(%Device{
        device_code: "LAMP-ROUTE-DUAL-001",
        name: "Route Dual Lamp",
        latitude: -6.214,
        longitude: 106.82,
        installation_address: "Route Dual Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0",
        connectivity_status: :offline,
        lamp_status: :offline,
        brightness_level: 0
      })

    Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, "repairs")
    admin = create_admin()
    {:ok, dashboard, _html} = live(log_in_admin(conn, admin), ~p"/admin/dashboard")
    {:ok, public_map, _html} = live(recycle(conn), ~p"/public-map")

    render_hook(dashboard, "select_device", %{"id" => device.id})
    assert has_element?(dashboard, "#admin-map-dispatch-drawer")
    dashboard |> element("#dispatch-technician-from-map") |> render_click()

    assert_receive {:repair_dispatched, dispatch}, 500
    assert dispatch.device_id == device.id
    assert :ok = perform_job(SmartCityLamp.Workers.RepairWorker, %{dispatch_id: dispatch.id})
    assert_push_event(public_map, "repair_status_updated", %{device_id: device_id})
    assert device_id == device.id
    assert_receive {:repair_status_updated, %{status: :repairing}}, 500
    assert_receive {:repair_completed, %{status: :completed}, _device}, 500
  end

  test "online device shows live conditions instead of repair action", %{conn: conn} do
    device =
      Repo.insert!(%Device{
        device_code: "LAMP-ONLINE-DRAWER-001",
        name: "Online Drawer Lamp",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Online Drawer Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0",
        connectivity_status: :online
      })

    assert :ok = LiveSensorBroadcaster.broadcast_device(device)
    admin = create_admin()
    {:ok, dashboard, _html} = live(log_in_admin(conn, admin), ~p"/admin/dashboard")

    render_hook(dashboard, "select_device", %{"id" => device.id})

    assert has_element?(dashboard, "#admin-device-environment")
    refute has_element?(dashboard, "#dispatch-technician-from-map")
  end
end
