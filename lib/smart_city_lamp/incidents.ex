defmodule SmartCityLamp.Incidents do
  import Ecto.Query, warn: false

  require Logger

  alias Ecto.Multi
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Incidents.Incident
  alias SmartCityLamp.Incidents.IncidentEvent
  alias SmartCityLamp.Incidents.VandalismDetectionEngine
  alias SmartCityLamp.Monitoring.ActivityDetectionEngine
  alias SmartCityLamp.Monitoring.EnvironmentDetectionEngine
  alias SmartCityLamp.Repo

  @cooldown_seconds 300
  @active_statuses [:open, :acknowledged, :investigating]
  @topic "incidents"

  def evaluate_telemetry(%Device{} = device, telemetry, previous, recent) do
    vandalism = VandalismDetectionEngine.detect(telemetry, previous, recent)
    environment = EnvironmentDetectionEngine.detect(telemetry)
    activity = ActivityDetectionEngine.detect(telemetry)

    with {:ok, device} <- update_derived_statuses(device, vandalism, environment, activity) do
      incidents =
        vandalism_incidents(vandalism) ++
          operational_incidents(telemetry) ++
          environment_incidents(environment) ++ activity_incidents(activity)

      created =
        Enum.reduce(incidents, [], fn attrs, created ->
          case create_detected_incident(device, attrs) do
            {:ok, incident, :created} ->
              [incident | created]

            {:ok, _incident, :cooldown} ->
              created

            {:error, changeset} ->
              Logger.error("incident creation failed",
                device_id: device.id,
                device_code: device.device_code,
                event_type: "incident_creation_failed",
                errors: inspect(changeset.errors),
                timestamp: DateTime.utc_now()
              )

              created
          end
        end)

      {:ok, device, Enum.reverse(created),
       %{vandalism: vandalism, environment: environment, activity: activity}}
    end
  end

  def list_active_incidents do
    events_query = from event in IncidentEvent, order_by: [asc: event.inserted_at]

    Repo.all(
      from incident in Incident,
        where: incident.status in ^@active_statuses,
        order_by: [desc: incident.detected_at],
        preload: [:device, events: ^events_query]
    )
  end

  def list_incidents do
    Repo.all(
      from incident in Incident,
        order_by: [desc: incident.detected_at],
        preload: [:device]
    )
  end

  def list_for_device(device_id, limit \\ 30) do
    events_query = from event in IncidentEvent, order_by: [asc: event.inserted_at]

    Repo.all(
      from incident in Incident,
        where: incident.device_id == ^device_id,
        order_by: [desc: incident.detected_at],
        limit: ^limit,
        preload: [events: ^events_query]
    )
  end

  def get_incident!(id), do: Repo.get!(Incident, id) |> Repo.preload([:device, :events])

  def summary do
    base = from incident in Incident, where: incident.status in ^@active_statuses

    %{
      active: Repo.aggregate(base, :count),
      critical:
        Repo.aggregate(from(incident in base, where: incident.severity == :critical), :count)
    }
  end

  def acknowledge(id, actor \\ "operator") do
    transition(id, :acknowledged, actor, "Incident acknowledged")
  end

  def resolve(id, actor \\ "operator", notes \\ "Resolved from monitoring dashboard") do
    transition(id, :resolved, actor, notes)
  end

  def ensure_device_offline(%Device{} = device, detected_at \\ DateTime.utc_now()) do
    create_detected_incident(device, %{
      incident_type: :device_offline,
      severity: :high,
      confidence_score: 100,
      title: "Device heartbeat lost",
      description: "No telemetry heartbeat was received for more than 180 seconds.",
      detected_signals: ["heartbeat_timeout"],
      detected_at: detected_at
    })
  end

  def record_device_recovery(%Device{} = device) do
    query =
      from incident in Incident,
        where:
          incident.device_id == ^device.id and incident.incident_type == :device_offline and
            incident.status in ^@active_statuses,
        order_by: [desc: incident.detected_at],
        limit: 1

    case Repo.one(query) do
      nil ->
        :ok

      incident ->
        %IncidentEvent{incident_id: incident.id}
        |> IncidentEvent.changeset(%{
          event_type: "device_recovered",
          actor: "heartbeat_checker",
          notes: "Device telemetry connection recovered",
          metadata: %{connectivity_status: "ONLINE"}
        })
        |> Repo.insert()
        |> case do
          {:ok, _event} ->
            broadcast(
              {:incident_updated, Repo.preload(incident, [:device, :events], force: true)}
            )

            :ok

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def subscribe, do: Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, @topic)

  defp create_detected_incident(device, attrs) do
    detected_at = Map.get(attrs, :detected_at, DateTime.utc_now())

    case in_cooldown(device.id, attrs.incident_type, detected_at) do
      %Incident{} = incident ->
        {:ok, incident, :cooldown}

      nil ->
        incident_changeset =
          Incident.detection_changeset(
            %Incident{device_id: device.id},
            Map.put(attrs, :detected_at, detected_at)
          )

        Multi.new()
        |> Multi.insert(:incident, incident_changeset)
        |> Multi.insert(:event, fn %{incident: incident} ->
          IncidentEvent.changeset(%IncidentEvent{incident_id: incident.id}, %{
            event_type: "detected",
            actor: "detection_engine",
            notes: incident.description,
            metadata: %{signals: incident.detected_signals, score: incident.confidence_score}
          })
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{incident: incident}} ->
            incident = Repo.preload(incident, [:device, :events])
            broadcast({:incident_created, incident})

            Logger.warning("incident created",
              device_id: device.id,
              device_code: device.device_code,
              incident_id: incident.id,
              event_type: "incident_created",
              timestamp: DateTime.utc_now()
            )

            {:ok, incident, :created}

          {:error, _operation, changeset, _changes} ->
            {:error, changeset}
        end
    end
  end

  defp in_cooldown(device_id, incident_type, detected_at) do
    cutoff = DateTime.add(detected_at, -@cooldown_seconds, :second)

    Repo.one(
      from incident in Incident,
        where:
          incident.device_id == ^device_id and incident.incident_type == ^incident_type and
            incident.detected_at >= ^cutoff,
        order_by: [desc: incident.detected_at],
        limit: 1
    )
  end

  defp transition(id, target_status, actor, notes) do
    incident = Repo.get!(Incident, id)
    previous_status = incident.status

    if allowed_transition?(incident.status, target_status) do
      now = DateTime.utc_now()

      attrs =
        %{status: target_status}
        |> maybe_put(target_status == :acknowledged, :acknowledged_at, now)
        |> maybe_put(target_status == :resolved, :resolved_at, now)
        |> maybe_put(target_status == :resolved, :resolution_notes, notes)

      Multi.new()
      |> Multi.update(:incident, Incident.lifecycle_changeset(incident, attrs))
      |> Multi.insert(:event, fn %{incident: incident} ->
        IncidentEvent.changeset(%IncidentEvent{incident_id: incident.id}, %{
          event_type: Atom.to_string(target_status),
          actor: actor,
          notes: notes,
          metadata: %{from: previous_status, to: target_status}
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{incident: incident}} ->
          incident = Repo.preload(incident, [:device, :events], force: true)
          broadcast({:incident_updated, incident})
          {:ok, incident}

        {:error, _operation, changeset, _changes} ->
          {:error, changeset}
      end
    else
      {:error, :invalid_transition}
    end
  end

  defp allowed_transition?(:open, status), do: status in [:acknowledged, :resolved, :false_alarm]

  defp allowed_transition?(:acknowledged, status),
    do: status in [:investigating, :resolved, :false_alarm]

  defp allowed_transition?(:investigating, status), do: status in [:resolved, :false_alarm]
  defp allowed_transition?(_current, _target), do: false

  defp update_derived_statuses(device, vandalism, environment, activity) do
    device
    |> Ecto.Changeset.change(%{
      security_status: vandalism.status,
      environment_status: environment.status,
      crowd_level: activity.crowd_level,
      traffic_level: activity.traffic_level
    })
    |> Repo.update()
  end

  defp vandalism_incidents(%{status: :safe}), do: []

  defp vandalism_incidents(result) do
    [
      %{
        incident_type: :suspected_vandalism,
        severity: vandalism_severity(result.status),
        confidence_score: result.score,
        title: "Suspicious activity detected",
        description: "Multiple physical-security signals were detected within 30 seconds.",
        detected_signals: stringify(result.signals)
      }
    ]
  end

  defp operational_incidents(telemetry) do
    []
    |> add_incident(telemetry.current <= 0.01 and telemetry.power_watt <= 0.1, %{
      incident_type: :power_failure,
      severity: :high,
      confidence_score: 90,
      title: "Lamp power failure",
      description: "Current and power consumption dropped to zero.",
      detected_signals: ["current_disconnected", "power_lost"]
    })
    |> add_incident(telemetry.led_temperature >= 85, %{
      incident_type: :overheat,
      severity: :critical,
      confidence_score: 95,
      title: "LED assembly overheated",
      description: "LED temperature exceeded the safe operating threshold.",
      detected_signals: ["high_led_temperature"]
    })
  end

  defp environment_incidents(environment) do
    []
    |> add_incident(
      environment.status == :flood_risk,
      environment_attrs(:flood_warning, :critical, 95, "Flood risk detected", environment.signals)
    )
    |> add_incident(
      environment.status == :heavy_rain,
      environment_attrs(:heavy_rain, :medium, 70, "Heavy rain detected", environment.signals)
    )
    |> add_incident(
      environment.status == :poor_air,
      environment_attrs(
        :poor_air_quality,
        environment.severity,
        80,
        "Poor air quality detected",
        environment.signals
      )
    )
    |> add_incident(
      :high_noise in environment.signals,
      environment_attrs(:high_noise, :medium, 70, "High environmental noise", [:high_noise])
    )
  end

  defp activity_incidents(activity) do
    []
    |> add_incident(activity.crowd_level in [:high, :very_high], %{
      incident_type: :high_crowd,
      severity: if(activity.crowd_level == :very_high, do: :high, else: :medium),
      confidence_score: 80,
      title: "High pedestrian activity",
      description: "Pedestrian count exceeded the configured activity threshold.",
      detected_signals: ["high_crowd"]
    })
    |> add_incident(activity.traffic_level == :congested, %{
      incident_type: :traffic_congestion,
      severity: :high,
      confidence_score: 85,
      title: "Traffic congestion detected",
      description: "High vehicle count and low average speed indicate congestion.",
      detected_signals: ["traffic_congestion"]
    })
  end

  defp environment_attrs(type, severity, score, title, signals) do
    %{
      incident_type: type,
      severity: severity,
      confidence_score: score,
      title: title,
      description: "Environmental telemetry crossed configured safety thresholds.",
      detected_signals: stringify(signals)
    }
  end

  defp vandalism_severity(:warning), do: :medium
  defp vandalism_severity(:suspected_vandalism), do: :high
  defp vandalism_severity(:critical), do: :critical

  defp stringify(signals), do: Enum.map(signals, &Atom.to_string/1)
  defp add_incident(incidents, true, attrs), do: incidents ++ [attrs]
  defp add_incident(incidents, false, _attrs), do: incidents

  defp maybe_put(map, true, key, value), do: Map.put(map, key, value)
  defp maybe_put(map, false, _key, _value), do: map

  defp broadcast(message), do: Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, @topic, message)
end
