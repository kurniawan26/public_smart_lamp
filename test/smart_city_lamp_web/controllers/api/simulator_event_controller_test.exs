defmodule SmartCityLampWeb.Api.SimulatorEventControllerTest do
  use SmartCityLampWeb.ConnCase

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Simulations.RateLimiter

  setup do
    RateLimiter.reset()

    device =
      Repo.insert!(%Device{
        device_code: "LAMP-PUBLIC-API-001",
        name: "Public API Lamp",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Public API Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    %{device: device}
  end

  test "valid event runs a simulation and ignores arbitrary telemetry fields", %{
    conn: conn,
    device: device
  } do
    conn =
      post(conn, ~p"/api/simulator/events", %{
        "device_code" => device.device_code,
        "event" => "HIT_LAMP",
        "vibration" => 99_999,
        "severity" => "CRITICAL"
      })

    assert %{
             "data" => %{
               "event" => "HIT_LAMP",
               "device_code" => "LAMP-PUBLIC-API-001",
               "telemetry_id" => telemetry_id
             },
             "errors" => []
           } = json_response(conn, 201)

    telemetry = SmartCityLamp.Telemetry.latest_for_device(device.id)
    assert telemetry.id == telemetry_id
    assert telemetry.vibration == 0.92
  end

  test "unsupported event returns a consistent error", %{conn: conn, device: device} do
    conn =
      post(conn, ~p"/api/simulator/events", %{
        "device_code" => device.device_code,
        "event" => "DROP_DATABASE"
      })

    assert %{"data" => nil, "errors" => [%{"code" => "INVALID_SIMULATION_EVENT"}]} =
             json_response(conn, 422)
  end

  test "public API cannot recover a device", %{conn: conn, device: device} do
    conn =
      post(conn, ~p"/api/simulator/events", %{
        "device_code" => device.device_code,
        "event" => "RECOVER_DEVICE"
      })

    assert %{"errors" => [%{"code" => "INVALID_SIMULATION_EVENT"}]} = json_response(conn, 422)
  end
end
