defmodule SmartCityLamp.Telemetry do
  import Ecto.Query, warn: false

  require Logger

  alias Ecto.Multi
  alias SmartCityLamp.Devices
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Telemetry.TelemetryRecord

  @dashboard_topic "dashboard"
  @telemetry_topic "telemetry"

  def ingest(attrs) when is_map(attrs) do
    with {:ok, device_code} <- fetch_device_code(attrs),
         %Device{} = device <- Devices.get_device_by_code(device_code) do
      telemetry_attrs = Map.drop(attrs, ["device_code", :device_code])

      changeset =
        TelemetryRecord.changeset(%TelemetryRecord{device_id: device.id}, telemetry_attrs)

      previous = latest_for_device(device.id)
      recent = recent_window(device.id, Ecto.Changeset.get_field(changeset, :recorded_at))

      Multi.new()
      |> Multi.insert(:telemetry, changeset)
      |> Multi.update(:device, device_update_changeset(device, changeset))
      |> Repo.transaction()
      |> handle_ingestion(device_code, previous, recent, device.connectivity_status)
    else
      nil -> {:error, :unknown_device}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_recent(limit \\ 10) do
    Repo.all(
      from record in TelemetryRecord,
        order_by: [desc: record.recorded_at],
        limit: ^limit,
        preload: [:device]
    )
  end

  def latest_for_device(device_id) do
    Repo.one(
      from record in TelemetryRecord,
        where: record.device_id == ^device_id,
        order_by: [desc: record.recorded_at],
        limit: 1
    )
  end

  def history_for_device(device_id, limit \\ 30) do
    Repo.all(
      from record in TelemetryRecord,
        where: record.device_id == ^device_id,
        order_by: [desc: record.recorded_at],
        limit: ^limit
    )
    |> Enum.reverse()
  end

  def subscribe_dashboard, do: Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, @dashboard_topic)
  def subscribe_telemetry, do: Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, @telemetry_topic)

  defp recent_window(_device_id, nil), do: []

  defp recent_window(device_id, recorded_at) do
    cutoff = DateTime.add(recorded_at, -30, :second)

    Repo.all(
      from record in TelemetryRecord,
        where:
          record.device_id == ^device_id and record.recorded_at >= ^cutoff and
            record.recorded_at <= ^recorded_at,
        order_by: [desc: record.recorded_at]
    )
  end

  defp fetch_device_code(attrs) do
    case Map.get(attrs, "device_code") || Map.get(attrs, :device_code) do
      code when is_binary(code) and code != "" -> {:ok, code}
      _ -> {:error, :device_code_required}
    end
  end

  defp device_update_changeset(device, telemetry_changeset) do
    if telemetry_changeset.valid? do
      Ecto.Changeset.change(device, %{
        latitude: Ecto.Changeset.get_field(telemetry_changeset, :latitude),
        longitude: Ecto.Changeset.get_field(telemetry_changeset, :longitude),
        brightness_level: Ecto.Changeset.get_field(telemetry_changeset, :brightness_level),
        connectivity_status: :online,
        lamp_status: lamp_status(telemetry_changeset),
        last_seen_at: Ecto.Changeset.get_field(telemetry_changeset, :recorded_at)
      })
    else
      device
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:base, "telemetry is invalid")
    end
  end

  defp lamp_status(changeset) do
    current = Ecto.Changeset.get_field(changeset, :current)
    power = Ecto.Changeset.get_field(changeset, :power_watt)
    temperature = Ecto.Changeset.get_field(changeset, :led_temperature)
    brightness = Ecto.Changeset.get_field(changeset, :brightness_level)

    cond do
      temperature >= 85 -> :overheated
      current <= 0.01 and power <= 0.1 -> :power_failure
      brightness < 70 -> :dimmed
      true -> :normal
    end
  end

  defp handle_ingestion(
         {:ok, %{telemetry: telemetry, device: device}},
         device_code,
         previous,
         recent,
         previous_connectivity
       ) do
    device =
      case Incidents.evaluate_telemetry(device, telemetry, previous, recent) do
        {:ok, evaluated_device, _incidents, _detections} -> evaluated_device
        {:error, _reason} -> device
      end

    telemetry = Repo.preload(telemetry, :device, force: true)

    if previous_connectivity == :offline do
      _result =
        Devices.record_event(device, %{
          event_type: "device_recovered",
          actor: "telemetry_ingestion",
          notes: "Device returned online after telemetry was received",
          metadata: %{from: "OFFLINE", to: "ONLINE"}
        })

      Incidents.record_device_recovery(device)
    end

    broadcast(@telemetry_topic, {:telemetry_received, telemetry})
    broadcast("device:#{device.id}", {:telemetry_received, telemetry})
    broadcast("devices", {:device_updated, device})
    broadcast(@dashboard_topic, {:dashboard_updated, device, telemetry})

    broadcast(
      @dashboard_topic,
      {:dashboard_summary_updated, SmartCityLamp.Monitoring.summary(Devices.list_devices())}
    )

    Logger.info("telemetry received",
      device_id: device.id,
      device_code: device_code,
      event_type: "telemetry_received",
      timestamp: DateTime.utc_now()
    )

    {:ok, telemetry, device}
  end

  defp handle_ingestion(
         {:error, _operation, changeset, _changes},
         _device_code,
         _previous,
         _recent,
         _previous_connectivity
       ),
       do: {:error, changeset}

  defp broadcast(topic, message),
    do: Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, topic, message)
end
