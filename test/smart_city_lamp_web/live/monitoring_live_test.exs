defmodule SmartCityLampWeb.MonitoringLiveTest do
  use SmartCityLampWeb.ConnCase
  use Oban.Testing, repo: SmartCityLamp.Repo

  import Phoenix.LiveViewTest

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Simulations.LiveSensorBroadcaster
  alias SmartCityLamp.Telemetry

  setup do
    SmartCityLamp.Simulations.RateLimiter.reset()

    device =
      Repo.insert!(%Device{
        device_code: "LAMP-LIVE-001",
        name: "LiveView Device",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Jakarta Test Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    %{device: device, admin: create_admin()}
  end

  test "renders summary, device registry, and Leaflet map", %{
    conn: conn,
    device: device,
    admin: admin
  } do
    {:ok, view, _html} = live(log_in_admin(conn, admin), ~p"/admin/dashboard")

    assert has_element?(view, "#device-summary")
    assert has_element?(view, "#device-map[data-devices]")
    assert has_element?(view, "#device-list")
    assert has_element?(view, "#device-#{device.id}")
  end

  test "dashboard receives telemetry through PubSub without reload", %{
    conn: conn,
    device: device,
    admin: admin
  } do
    {:ok, view, _html} = live(log_in_admin(conn, admin), ~p"/admin/dashboard")
    assert {:ok, _telemetry, _device} = Telemetry.ingest(telemetry_payload(device.device_code))

    assert has_element?(view, "#recent-telemetry article")
    assert has_element?(view, "#device-map[data-devices]")
  end

  test "public map drawer runs allowlisted scenarios with one click", %{
    conn: conn,
    device: device
  } do
    {:ok, view, _html} = live(conn, ~p"/public-map")

    render_hook(view, "select_device", %{"id" => device.id})
    assert has_element?(view, "#public-device-drawer")
    assert has_element?(view, "#drawer-scenario-buttons")
    refute has_element?(view, "#scenario-recover_device")
    refute has_element?(view, "#telemetry-form")
    view |> element("#scenario-hit_lamp") |> render_click()
    assert Telemetry.latest_for_device(device.id)
  end

  test "critical signals render an alert and support incident lifecycle", %{
    conn: conn,
    device: device,
    admin: admin
  } do
    {:ok, view, _html} = live(log_in_admin(conn, admin), ~p"/admin/dashboard")

    assert {:ok, _telemetry, _device} =
             Telemetry.ingest(
               telemetry_payload(device.device_code)
               |> Map.merge(%{
                 "vibration" => 0.95,
                 "cabinet_open" => true,
                 "current" => 0.0,
                 "power_watt" => 0.0,
                 "light_intensity" => 0.0
               })
             )

    incident =
      Incidents.list_active_incidents()
      |> Enum.find(&(&1.incident_type == :suspected_vandalism))

    assert has_element?(view, "#active-incidents article")
    assert has_element?(view, "#device-map[data-devices*=\"critical\"]")

    view |> element("#acknowledge-incident-#{incident.id}") |> render_click()
    refute has_element?(view, "#acknowledge-incident-#{incident.id}")
    assert has_element?(view, "#resolve-incident-#{incident.id}")

    view |> element("#resolve-incident-#{incident.id}") |> render_click()
    assert has_element?(view, "#resolve-incident-modal")

    view
    |> form("#resolve-incident-form",
      resolution: %{"resolution_notes" => "Lamp inspected and secured"}
    )
    |> render_submit()

    refute has_element?(view, "#resolve-incident-#{incident.id}")
  end

  test "device detail renders charts, audit panels, and executes remote command", %{
    conn: conn,
    device: device,
    admin: admin
  } do
    assert {:ok, _, _} = Telemetry.ingest(telemetry_payload(device.device_code))
    {:ok, view, _html} = live(log_in_admin(conn, admin), ~p"/admin/devices/#{device.id}")

    assert has_element?(view, "#device-profile")
    assert has_element?(view, "#telemetry-charts svg")
    assert has_element?(view, "#remote-command-form")
    assert has_element?(view, "#device-audit-panel")
    assert has_element?(view, "#admin-recover-device")

    assert :ok = LiveSensorBroadcaster.broadcast_device(Repo.reload!(device))
    _ = :sys.get_state(view.pid)
    assert has_element?(view, "#live-device-sensors")

    view
    |> form("#remote-command-form",
      command: %{"command_type" => "SET_BRIGHTNESS", "brightness_level" => "40"}
    )
    |> render_submit()

    assert Repo.reload!(device).brightness_level == 40
    assert has_element?(view, "#device-commands article")
    assert has_element?(view, "#device-events article")
  end

  test "only admin detail can recover an offline device", %{
    conn: conn,
    device: device,
    admin: admin
  } do
    {:ok, offline} = Devices.set_simulated_offline(device)
    Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, "device:#{offline.id}")
    {:ok, view, _html} = live(log_in_admin(conn, admin), ~p"/admin/devices/#{offline.id}")

    view |> element("#admin-recover-device") |> render_click()

    assert_receive {:repair_dispatched, dispatch}, 500
    assert :ok = perform_job(SmartCityLamp.Workers.RepairWorker, %{dispatch_id: dispatch.id})
    assert_receive {:repair_status_updated, %{status: :repairing}}, 500
    assert_receive {:repair_completed, %{status: :completed}, _device}, 500
    _ = :sys.get_state(view.pid)

    recovered = Repo.reload!(device)
    assert recovered.connectivity_status == :online
    assert recovered.lamp_status == :normal
    assert recovered.security_status == :safe
    assert has_element?(view, "#technician-route-map")
  end

  defp telemetry_payload(device_code) do
    %{
      "device_code" => device_code,
      "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "voltage" => 220.4,
      "current" => 0.42,
      "power_watt" => 92.5,
      "brightness_level" => 80,
      "light_intensity" => 700,
      "led_temperature" => 48.2,
      "ambient_temperature" => 31.5,
      "humidity" => 76,
      "pm25" => 22,
      "pm10" => 40,
      "rain_level" => 0,
      "water_level_cm" => 0,
      "noise_db" => 62,
      "vibration" => 0.03,
      "tilt_angle" => 2.1,
      "cabinet_open" => false,
      "pedestrian_count" => 12,
      "vehicle_count" => 18,
      "average_vehicle_speed" => 35,
      "latitude" => -6.2,
      "longitude" => 106.8
    }
  end
end
