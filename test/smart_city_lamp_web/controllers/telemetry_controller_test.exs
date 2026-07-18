defmodule SmartCityLampWeb.TelemetryControllerTest do
  use SmartCityLampWeb.ConnCase

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repo

  setup do
    device =
      Repo.insert!(%Device{
        device_code: "LAMP-API-001",
        name: "API Device",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "API Test Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    %{device: device}
  end

  test "POST /api/telemetry ingests a valid payload", %{conn: conn, device: device} do
    conn = post(conn, ~p"/api/telemetry", telemetry_payload(device.device_code))

    assert %{
             "data" => %{"device_code" => "LAMP-API-001", "brightness_level" => 100},
             "errors" => []
           } = json_response(conn, 201)
  end

  test "POST /api/telemetry returns a consistent validation error", %{conn: conn} do
    conn = post(conn, ~p"/api/telemetry", %{"device_code" => "LAMP-API-001"})

    assert %{
             "data" => nil,
             "errors" => [%{"code" => "VALIDATION_ERROR", "fields" => fields}]
           } = json_response(conn, 422)

    assert Map.has_key?(fields, "recorded_at")
  end

  test "POST /api/telemetry rejects unknown devices", %{conn: conn} do
    conn = post(conn, ~p"/api/telemetry", telemetry_payload("UNKNOWN"))
    assert %{"errors" => [%{"code" => "UNKNOWN_DEVICE"}]} = json_response(conn, 404)
  end

  defp telemetry_payload(device_code) do
    %{
      "device_code" => device_code,
      "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "voltage" => 220.4,
      "current" => 0.42,
      "power_watt" => 92.5,
      "brightness_level" => 100,
      "light_intensity" => 850,
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
