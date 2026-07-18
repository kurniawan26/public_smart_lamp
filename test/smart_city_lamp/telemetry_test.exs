defmodule SmartCityLamp.TelemetryTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Telemetry
  alias SmartCityLamp.Telemetry.TelemetryRecord

  test "telemetry changeset validates required sensors and ranges" do
    device = device_fixture()

    changeset =
      TelemetryRecord.changeset(
        %TelemetryRecord{device_id: device.id},
        telemetry_attrs(%{"brightness_level" => 101, "humidity" => -1})
      )

    refute changeset.valid?
    assert "must be less than or equal to 100" in errors_on(changeset).brightness_level
    assert "must be greater than or equal to 0" in errors_on(changeset).humidity
  end

  test "ingestion persists telemetry, updates device, and broadcasts dashboard event" do
    device = device_fixture()
    Telemetry.subscribe_dashboard()

    attrs = telemetry_attrs(%{"device_code" => device.device_code, "brightness_level" => 55})
    assert {:ok, telemetry, updated_device} = Telemetry.ingest(attrs)

    assert telemetry.device_id == device.id
    assert updated_device.brightness_level == 55
    assert updated_device.lamp_status == :dimmed
    assert_receive {:dashboard_updated, ^updated_device, ^telemetry}
  end

  test "ingestion rejects unknown devices" do
    assert {:error, :unknown_device} =
             Telemetry.ingest(telemetry_attrs(%{"device_code" => "UNKNOWN-001"}))
  end

  defp device_fixture do
    Repo.insert!(%Device{
      device_code: "LAMP-TELEMETRY-001",
      name: "Telemetry Device",
      latitude: -6.2,
      longitude: 106.8,
      installation_address: "Test Area",
      installation_date: ~D[2026-01-01],
      firmware_version: "1.0.0"
    })
  end

  defp telemetry_attrs(overrides) do
    Map.merge(
      %{
        "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "voltage" => 220.4,
        "current" => 0.42,
        "power_watt" => 92.5,
        "brightness_level" => 100,
        "light_intensity" => 850.0,
        "led_temperature" => 48.2,
        "ambient_temperature" => 31.5,
        "humidity" => 76.0,
        "pm25" => 22.0,
        "pm10" => 40.0,
        "rain_level" => 0.0,
        "water_level_cm" => 0.0,
        "noise_db" => 62.0,
        "vibration" => 0.03,
        "tilt_angle" => 2.1,
        "cabinet_open" => false,
        "pedestrian_count" => 12,
        "vehicle_count" => 18,
        "average_vehicle_speed" => 35.0,
        "latitude" => -6.2,
        "longitude" => 106.8
      },
      overrides
    )
  end
end
