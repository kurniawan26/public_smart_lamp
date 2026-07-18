defmodule SmartCityLamp.Devices.Device do
  use Ecto.Schema
  import Ecto.Changeset

  @device_statuses [active: "ACTIVE", maintenance: "MAINTENANCE", disabled: "DISABLED"]
  @lamp_statuses [
    normal: "NORMAL",
    dimmed: "DIMMED",
    flickering: "FLICKERING",
    power_failure: "POWER_FAILURE",
    overheated: "OVERHEATED",
    offline: "OFFLINE"
  ]
  @security_statuses [
    safe: "SAFE",
    warning: "WARNING",
    suspected_vandalism: "SUSPECTED_VANDALISM",
    critical: "CRITICAL"
  ]
  @environment_statuses [
    normal: "NORMAL",
    warning: "WARNING",
    poor_air: "POOR_AIR",
    heavy_rain: "HEAVY_RAIN",
    flood_risk: "FLOOD_RISK"
  ]
  @crowd_levels [low: "LOW", medium: "MEDIUM", high: "HIGH", very_high: "VERY_HIGH"]
  @traffic_levels [low: "LOW", medium: "MEDIUM", high: "HIGH", congested: "CONGESTED"]
  @connectivity_statuses [online: "ONLINE", degraded: "DEGRADED", offline: "OFFLINE"]

  schema "devices" do
    field :device_code, :string
    field :name, :string
    field :description, :string
    field :latitude, :float
    field :longitude, :float
    field :installation_address, :string
    field :installation_date, :date
    field :status, Ecto.Enum, values: @device_statuses, default: :active
    field :lamp_status, Ecto.Enum, values: @lamp_statuses, default: :normal
    field :security_status, Ecto.Enum, values: @security_statuses, default: :safe
    field :environment_status, Ecto.Enum, values: @environment_statuses, default: :normal
    field :crowd_level, Ecto.Enum, values: @crowd_levels, default: :low
    field :traffic_level, Ecto.Enum, values: @traffic_levels, default: :low
    field :connectivity_status, Ecto.Enum, values: @connectivity_statuses, default: :online
    field :brightness_level, :integer, default: 100
    field :firmware_version, :string
    field :last_seen_at, :utc_datetime_usec

    has_many :telemetry_records, SmartCityLamp.Telemetry.TelemetryRecord
    has_many :incidents, SmartCityLamp.Incidents.Incident
    has_many :commands, SmartCityLamp.Commands.DeviceCommand
    has_many :events, SmartCityLamp.Devices.DeviceEvent

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(device, attrs) do
    device
    |> cast(attrs, [
      :device_code,
      :name,
      :description,
      :latitude,
      :longitude,
      :installation_address,
      :installation_date,
      :status,
      :lamp_status,
      :security_status,
      :environment_status,
      :crowd_level,
      :traffic_level,
      :connectivity_status,
      :brightness_level,
      :firmware_version,
      :last_seen_at
    ])
    |> validate_required([
      :device_code,
      :name,
      :latitude,
      :longitude,
      :installation_address,
      :installation_date,
      :status,
      :lamp_status,
      :security_status,
      :environment_status,
      :crowd_level,
      :traffic_level,
      :connectivity_status,
      :brightness_level,
      :firmware_version
    ])
    |> validate_length(:device_code, min: 3, max: 64)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:brightness_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint(:device_code)
    |> check_constraint(:latitude, name: :valid_latitude)
    |> check_constraint(:longitude, name: :valid_longitude)
    |> check_constraint(:brightness_level, name: :valid_brightness)
  end
end
