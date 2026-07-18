defmodule SmartCityLamp.Monitoring.EnvironmentDetectionEngine do
  @moduledoc "Derives environmental status and severity from one validated telemetry record."

  @thresholds %{
    hot_temperature: 38,
    very_humid: 90,
    poor_air: 55,
    unhealthy_air: 150,
    heavy_rain: 70,
    flood_warning: 20,
    flood_risk: 40,
    high_noise: 85
  }

  def detect(telemetry) do
    signals =
      []
      |> add(telemetry.ambient_temperature > @thresholds.hot_temperature, :hot)
      |> add(telemetry.humidity > @thresholds.very_humid, :very_humid)
      |> add(telemetry.pm25 > @thresholds.poor_air, :poor_air)
      |> add(telemetry.pm25 > @thresholds.unhealthy_air, :unhealthy_air)
      |> add(telemetry.rain_level >= @thresholds.heavy_rain, :heavy_rain)
      |> add(telemetry.water_level_cm > @thresholds.flood_warning, :flood_warning)
      |> add(telemetry.water_level_cm > @thresholds.flood_risk, :high_water_level)
      |> add(telemetry.noise_db > @thresholds.high_noise, :high_noise)
      |> Enum.reverse()

    {status, severity} = classify(signals)
    %{status: status, signals: signals, severity: severity}
  end

  def thresholds, do: @thresholds

  defp classify(signals) do
    cond do
      :high_water_level in signals -> {:flood_risk, :critical}
      :flood_warning in signals -> {:warning, :high}
      :unhealthy_air in signals -> {:poor_air, :high}
      :heavy_rain in signals -> {:heavy_rain, :medium}
      :poor_air in signals -> {:poor_air, :medium}
      signals != [] -> {:warning, :low}
      true -> {:normal, :low}
    end
  end

  defp add(signals, true, signal), do: [signal | signals]
  defp add(signals, false, _signal), do: signals
end
