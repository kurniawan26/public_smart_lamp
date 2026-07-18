defmodule SmartCityLamp.Incidents.Incident do
  use Ecto.Schema
  import Ecto.Changeset

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Incidents.IncidentEvent

  @incident_types [
    suspected_vandalism: "SUSPECTED_VANDALISM",
    power_failure: "POWER_FAILURE",
    device_offline: "DEVICE_OFFLINE",
    cabinet_opened: "CABINET_OPENED",
    device_moved: "DEVICE_MOVED",
    overheat: "OVERHEAT",
    poor_air_quality: "POOR_AIR_QUALITY",
    heavy_rain: "HEAVY_RAIN",
    flood_warning: "FLOOD_WARNING",
    high_crowd: "HIGH_CROWD",
    traffic_congestion: "TRAFFIC_CONGESTION",
    high_noise: "HIGH_NOISE"
  ]
  @severities [low: "LOW", medium: "MEDIUM", high: "HIGH", critical: "CRITICAL"]
  @statuses [
    open: "OPEN",
    acknowledged: "ACKNOWLEDGED",
    investigating: "INVESTIGATING",
    resolved: "RESOLVED",
    false_alarm: "FALSE_ALARM"
  ]

  schema "incidents" do
    field :incident_type, Ecto.Enum, values: @incident_types
    field :severity, Ecto.Enum, values: @severities
    field :status, Ecto.Enum, values: @statuses, default: :open
    field :confidence_score, :integer
    field :title, :string
    field :description, :string
    field :detected_signals, {:array, :string}, default: []
    field :detected_at, :utc_datetime_usec
    field :acknowledged_at, :utc_datetime_usec
    field :resolved_at, :utc_datetime_usec
    field :assigned_to, :string
    field :resolution_notes, :string

    belongs_to :device, Device
    has_many :events, IncidentEvent

    timestamps(type: :utc_datetime_usec)
  end

  def detection_changeset(incident, attrs) do
    incident
    |> cast(attrs, [
      :incident_type,
      :severity,
      :confidence_score,
      :title,
      :description,
      :detected_signals,
      :detected_at
    ])
    |> validate_required([
      :device_id,
      :incident_type,
      :severity,
      :status,
      :confidence_score,
      :title,
      :description,
      :detected_at
    ])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:device_id)
    |> check_constraint(:confidence_score, name: :valid_confidence_score)
  end

  def lifecycle_changeset(incident, attrs) do
    incident
    |> cast(attrs, [:status, :acknowledged_at, :resolved_at, :assigned_to, :resolution_notes])
    |> validate_required([:status])
  end
end
