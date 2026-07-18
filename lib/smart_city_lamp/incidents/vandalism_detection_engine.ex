defmodule SmartCityLamp.Incidents.VandalismDetectionEngine do
  @moduledoc "Rule-based vandalism detection over a rolling 30-second telemetry window."

  @window_seconds 30
  @normal_voltage_min 180

  def detect(current, previous \\ nil, recent \\ [], options \\ []) do
    window = [current | within_window(recent, current.recorded_at)]

    scored_signals = [
      {:high_vibration, any?(window, &(&1.vibration > 0.8)), 30},
      {:cabinet_open, any?(window, & &1.cabinet_open), 40},
      {:current_disconnected, current_drop?(current, previous), 25},
      {:lamp_tilted, any?(window, &(abs(&1.tilt_angle) > 15)), 35},
      {:device_moved, moved?(current, previous), 50},
      {:offline_after_vibration, offline_after_vibration?(window, options), 30},
      {:light_lost_with_voltage,
       current.light_intensity <= 0.1 and current.voltage >= @normal_voltage_min, 25}
    ]

    signals = for {signal, true, _score} <- scored_signals, do: signal
    score = scored_signals |> Enum.filter(&elem(&1, 1)) |> Enum.sum_by(&elem(&1, 2)) |> min(100)
    status = status_for(score)

    %{
      score: score,
      status: status,
      suspected_vandalism: status in [:suspected_vandalism, :critical],
      signals: signals
    }
  end

  defp status_for(score) when score < 30, do: :safe
  defp status_for(score) when score < 50, do: :warning
  defp status_for(score) when score < 80, do: :suspected_vandalism
  defp status_for(_score), do: :critical

  defp current_drop?(_current, nil), do: false
  defp current_drop?(current, previous), do: previous.current > 0.1 and current.current <= 0.05

  defp moved?(_current, nil), do: false

  defp moved?(current, previous) do
    distance_meters(current.latitude, current.longitude, previous.latitude, previous.longitude) >
      20
  end

  defp offline_after_vibration?(window, options) do
    Keyword.get(options, :connectivity_status) == :offline and any?(window, &(&1.vibration > 0.8))
  end

  defp within_window(records, recorded_at) do
    cutoff = DateTime.add(recorded_at, -@window_seconds, :second)
    Enum.filter(records, &(DateTime.compare(&1.recorded_at, cutoff) in [:gt, :eq]))
  end

  defp any?(records, predicate), do: Enum.any?(records, predicate)

  defp distance_meters(lat1, lon1, lat2, lon2) do
    radius = 6_371_000
    latitude_delta = degrees_to_radians(lat2 - lat1)
    longitude_delta = degrees_to_radians(lon2 - lon1)

    a =
      :math.sin(latitude_delta / 2) ** 2 +
        :math.cos(degrees_to_radians(lat1)) * :math.cos(degrees_to_radians(lat2)) *
          :math.sin(longitude_delta / 2) ** 2

    radius * 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
  end

  defp degrees_to_radians(degrees), do: degrees * :math.pi() / 180
end
