defmodule SmartCityLamp.Monitoring.ActivityDetectionEngine do
  @moduledoc "Configurable crowd and traffic classification for validated telemetry."

  @thresholds %{
    crowd_low_max: 10,
    crowd_medium_max: 30,
    crowd_high_max: 70,
    traffic_low_max: 10,
    traffic_medium_max: 30,
    congestion_speed_max: 15
  }

  def detect(telemetry) do
    crowd_level = crowd_level(telemetry.pedestrian_count)
    traffic_level = traffic_level(telemetry.vehicle_count, telemetry.average_vehicle_speed)

    signals =
      []
      |> add(crowd_level in [:high, :very_high], :high_crowd)
      |> add(traffic_level == :congested, :traffic_congestion)
      |> Enum.reverse()

    %{crowd_level: crowd_level, traffic_level: traffic_level, signals: signals}
  end

  def thresholds, do: @thresholds

  def crowd_level(count) when count <= @thresholds.crowd_low_max, do: :low
  def crowd_level(count) when count <= @thresholds.crowd_medium_max, do: :medium
  def crowd_level(count) when count <= @thresholds.crowd_high_max, do: :high
  def crowd_level(_count), do: :very_high

  def traffic_level(count, _speed) when count <= @thresholds.traffic_low_max, do: :low
  def traffic_level(count, _speed) when count <= @thresholds.traffic_medium_max, do: :medium
  def traffic_level(_count, speed) when speed < @thresholds.congestion_speed_max, do: :congested
  def traffic_level(_count, _speed), do: :high

  defp add(signals, true, signal), do: [signal | signals]
  defp add(signals, false, _signal), do: signals
end
