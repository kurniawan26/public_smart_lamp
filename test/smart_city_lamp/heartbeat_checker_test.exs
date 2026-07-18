defmodule SmartCityLamp.HeartbeatCheckerTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Monitoring.HeartbeatChecker
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Workers.HeartbeatWorker

  test "connectivity thresholds derive online, degraded, and offline" do
    now = ~U[2026-07-18 10:00:00Z]

    assert HeartbeatChecker.connectivity_for(DateTime.add(now, -59, :second), now) == :online
    assert HeartbeatChecker.connectivity_for(DateTime.add(now, -61, :second), now) == :degraded
    assert HeartbeatChecker.connectivity_for(DateTime.add(now, -181, :second), now) == :offline
    assert HeartbeatChecker.connectivity_for(nil, now) == :offline
  end

  test "offline transition creates audit event and active incident" do
    now = DateTime.utc_now()
    device = device_fixture(DateTime.add(now, -181, :second))

    assert {:updated, offline_device} = HeartbeatChecker.check_device(device, now)
    assert offline_device.connectivity_status == :offline

    assert [%{event_type: "connectivity_changed"}] = Devices.list_events(device.id)
    assert [%{incident_type: :device_offline, status: :open}] = Incidents.list_active_incidents()
  end

  test "recovery adds incident audit event without closing it" do
    device = device_fixture(DateTime.add(DateTime.utc_now(), -181, :second))
    assert {:updated, offline_device} = HeartbeatChecker.check_device(device)
    assert :ok = Incidents.record_device_recovery(offline_device)

    [incident] = Incidents.list_active_incidents()
    assert incident.status == :open
    assert "device_recovered" in Enum.map(incident.events, & &1.event_type)
  end

  test "Oban heartbeat worker executes the checker" do
    _device = device_fixture(DateTime.add(DateTime.utc_now(), -181, :second))
    assert :ok = HeartbeatWorker.perform(%Oban.Job{})
    assert [%{incident_type: :device_offline}] = Incidents.list_active_incidents()
  end

  defp device_fixture(last_seen_at) do
    Repo.insert!(%Device{
      device_code: "LAMP-HEARTBEAT-#{System.unique_integer([:positive])}",
      name: "Heartbeat Device",
      latitude: -6.2,
      longitude: 106.8,
      installation_address: "Heartbeat Test Area",
      installation_date: ~D[2026-01-01],
      firmware_version: "1.0.0",
      last_seen_at: last_seen_at
    })
  end
end
