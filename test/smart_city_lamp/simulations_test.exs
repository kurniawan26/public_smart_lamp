defmodule SmartCityLamp.SimulationsTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Simulations
  alias SmartCityLamp.Simulations.RateLimiter
  alias SmartCityLamp.Telemetry

  setup do
    RateLimiter.reset()

    device =
      Repo.insert!(%Device{
        device_code: "LAMP-SIM-001",
        name: "Simulation Lamp",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Simulation Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    %{device: device}
  end

  test "allowlisted event builds and ingests backend-controlled telemetry", %{device: device} do
    assert {:ok, result} = Simulations.run_scenario(device, "HIT_LAMP", rate_key: "session:one")
    assert result.telemetry.vibration == 0.92
    assert result.device.security_status == :warning
    assert Telemetry.latest_for_device(device.id).id == result.telemetry.id
  end

  test "unknown events are rejected without telemetry", %{device: device} do
    assert {:error, :invalid_simulation_event} =
             Simulations.run_scenario(device, "SET_SEVERITY_CRITICAL",
               rate_key: "session:invalid"
             )

    refute Telemetry.latest_for_device(device.id)
  end

  test "per-device cooldown and per-session minute limit are enforced", %{device: device} do
    assert {:ok, _result} =
             Simulations.run_scenario(device, "HIT_LAMP", rate_key: "session:cooldown")

    assert {:error, :device_cooldown} =
             Simulations.run_scenario(device, "OPEN_CABINET", rate_key: "session:other")

    RateLimiter.reset()
    Enum.each(1..20, fn id -> assert :ok = RateLimiter.check("session:limit", 10_000 + id) end)
    assert {:error, :rate_limit_exceeded} = RateLimiter.check("session:limit", 20_000)
  end
end
