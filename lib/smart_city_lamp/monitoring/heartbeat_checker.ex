defmodule SmartCityLamp.Monitoring.HeartbeatChecker do
  @moduledoc "Checks persisted device heartbeat timestamps and derives connectivity status."

  require Logger

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Repo

  @degraded_after_seconds 60
  @offline_after_seconds 180

  def check_all(now \\ DateTime.utc_now()) do
    Devices.list_devices()
    |> Enum.map(&check_device(&1, now))
  end

  def check_device(%Device{} = device, now \\ DateTime.utc_now()) do
    target = connectivity_for(device.last_seen_at, now)

    if target == device.connectivity_status do
      {:unchanged, device}
    else
      previous = device.connectivity_status

      Repo.transaction(fn ->
        device =
          device
          |> Ecto.Changeset.change(%{connectivity_status: target})
          |> Repo.update!()

        {:ok, _event} =
          Devices.record_event(device, %{
            event_type: "connectivity_changed",
            actor: "heartbeat_checker",
            notes: "Connectivity changed from #{previous} to #{target}",
            metadata: %{from: previous, to: target, checked_at: DateTime.to_iso8601(now)}
          })

        device
      end)
      |> case do
        {:ok, updated_device} ->
          handle_transition(updated_device, previous, target, now)
          broadcast(updated_device)

          Logger.warning(log_message(target),
            device_id: updated_device.id,
            device_code: updated_device.device_code,
            event_type: log_event_type(target),
            connectivity_status: target,
            timestamp: now
          )

          {:updated, updated_device}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def connectivity_for(nil, _now), do: :offline

  def connectivity_for(last_seen_at, now) do
    age = DateTime.diff(now, last_seen_at, :second)

    cond do
      age > @offline_after_seconds -> :offline
      age > @degraded_after_seconds -> :degraded
      true -> :online
    end
  end

  def thresholds,
    do: %{
      degraded_after_seconds: @degraded_after_seconds,
      offline_after_seconds: @offline_after_seconds
    }

  defp handle_transition(device, _previous, :offline, now) do
    _result = Incidents.ensure_device_offline(device, now)
    :ok
  end

  defp handle_transition(device, :offline, :online, _now),
    do: Incidents.record_device_recovery(device)

  defp handle_transition(_device, _previous, _target, _now), do: :ok

  defp broadcast(device) do
    Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, "devices", {:device_updated, device})

    Phoenix.PubSub.broadcast(
      SmartCityLamp.PubSub,
      "device:#{device.id}",
      {:device_status_updated, device}
    )

    Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, "dashboard", {:device_status_updated, device})
  end

  defp log_message(:offline), do: "device offline"
  defp log_message(:online), do: "device recovered"
  defp log_message(:degraded), do: "device connectivity degraded"

  defp log_event_type(:offline), do: "device_offline"
  defp log_event_type(:online), do: "device_recovered"
  defp log_event_type(:degraded), do: "device_degraded"
end
