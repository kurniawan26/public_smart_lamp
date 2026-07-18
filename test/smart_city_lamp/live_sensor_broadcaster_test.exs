defmodule SmartCityLamp.LiveSensorBroadcasterTest do
  use SmartCityLamp.DataCase

  import Ecto.Query

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Simulations.LiveSensorBroadcaster
  alias SmartCityLamp.Telemetry.TelemetryRecord

  test "active device broadcasts random ephemeral sensor data without ingestion" do
    device = device_fixture("LAMP-LIVE-SENSOR-001")
    Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, "live_sensors")
    before_count = Repo.aggregate(from(record in TelemetryRecord), :count)

    assert :ok = LiveSensorBroadcaster.broadcast_device(device)
    assert_receive {:live_sensor_reading, device_id, reading}
    assert device_id == device.id
    assert reading.device_code == device.device_code
    assert reading.pm25 >= 8
    assert reading.noise_db >= 48
    assert reading.crowd_level in [:low, :medium, :high, :very_high]
    assert Repo.aggregate(from(record in TelemetryRecord), :count) == before_count
  end

  test "offline and power-failure devices do not broadcast" do
    Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, "live_sensors")

    offline =
      device_fixture("LAMP-LIVE-SENSOR-OFFLINE",
        connectivity_status: :offline,
        lamp_status: :offline
      )

    power_failure = device_fixture("LAMP-LIVE-SENSOR-POWER", lamp_status: :power_failure)

    assert :skipped = LiveSensorBroadcaster.broadcast_device(offline)
    assert :skipped = LiveSensorBroadcaster.broadcast_device(power_failure)
    refute_receive {:live_sensor_reading, _, _}
  end

  defp device_fixture(code, attrs \\ []) do
    defaults = [
      device_code: code,
      name: "Live Sensor Lamp",
      latitude: -6.2,
      longitude: 106.8,
      installation_address: "Live Sensor Area",
      installation_date: ~D[2026-01-01],
      firmware_version: "1.0.0"
    ]

    Repo.insert!(struct!(Device, Keyword.merge(defaults, attrs)))
  end
end
