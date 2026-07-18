defmodule SmartCityLamp.DetectionEnginesTest do
  use ExUnit.Case, async: true

  alias SmartCityLamp.Incidents.VandalismDetectionEngine
  alias SmartCityLamp.Monitoring.ActivityDetectionEngine
  alias SmartCityLamp.Monitoring.EnvironmentDetectionEngine
  alias SmartCityLamp.Telemetry.TelemetryRecord

  test "high vibration alone produces warning" do
    result = VandalismDetectionEngine.detect(telemetry(%{vibration: 0.9}))

    assert result.score == 30
    assert result.status == :warning
    assert result.signals == [:high_vibration]
    refute result.suspected_vandalism
  end

  test "high vibration and open cabinet produce suspected vandalism" do
    result = VandalismDetectionEngine.detect(telemetry(%{vibration: 0.9, cabinet_open: true}))

    assert result.score == 70
    assert result.status == :suspected_vandalism
    assert result.suspected_vandalism
  end

  test "high vibration, cabinet open, and power cut produce critical" do
    previous = telemetry(%{current: 0.42, recorded_at: DateTime.add(now(), -2, :second)})

    current =
      telemetry(%{
        vibration: 0.9,
        cabinet_open: true,
        current: 0.0,
        power_watt: 0.0,
        light_intensity: 0.0
      })

    result = VandalismDetectionEngine.detect(current, previous)

    assert result.score == 100
    assert result.status == :critical
    assert :current_disconnected in result.signals
    assert :light_lost_with_voltage in result.signals
  end

  test "environment engine prioritizes flood risk and retains signals" do
    result =
      EnvironmentDetectionEngine.detect(
        telemetry(%{rain_level: 95.0, humidity: 96.0, water_level_cm: 45.0})
      )

    assert result.status == :flood_risk
    assert result.severity == :critical
    assert :heavy_rain in result.signals
    assert :high_water_level in result.signals
  end

  test "activity engine classifies crowd and congestion" do
    result =
      ActivityDetectionEngine.detect(
        telemetry(%{pedestrian_count: 85, vehicle_count: 80, average_vehicle_speed: 8.0})
      )

    assert result.crowd_level == :very_high
    assert result.traffic_level == :congested
    assert result.signals == [:high_crowd, :traffic_congestion]
  end

  defp telemetry(overrides) do
    struct!(TelemetryRecord, Map.merge(defaults(), overrides))
  end

  defp defaults do
    %{
      recorded_at: now(),
      voltage: 220.0,
      current: 0.42,
      power_watt: 92.0,
      brightness_level: 100,
      light_intensity: 850.0,
      led_temperature: 48.0,
      ambient_temperature: 31.0,
      humidity: 70.0,
      pm25: 20.0,
      pm10: 30.0,
      rain_level: 0.0,
      water_level_cm: 0.0,
      noise_db: 60.0,
      vibration: 0.03,
      tilt_angle: 1.0,
      cabinet_open: false,
      pedestrian_count: 10,
      vehicle_count: 15,
      average_vehicle_speed: 35.0,
      latitude: -6.2,
      longitude: 106.8
    }
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
