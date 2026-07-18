defmodule SmartCityLamp.Telemetry.TelemetryRecord do
  use Ecto.Schema
  import Ecto.Changeset

  alias SmartCityLamp.Devices.Device

  @sensor_fields [
    :voltage,
    :current,
    :power_watt,
    :brightness_level,
    :light_intensity,
    :led_temperature,
    :ambient_temperature,
    :humidity,
    :pm25,
    :pm10,
    :rain_level,
    :water_level_cm,
    :noise_db,
    :vibration,
    :tilt_angle,
    :cabinet_open,
    :pedestrian_count,
    :vehicle_count,
    :average_vehicle_speed,
    :latitude,
    :longitude
  ]

  schema "telemetry_records" do
    field :recorded_at, :utc_datetime_usec
    field :voltage, :float
    field :current, :float
    field :power_watt, :float
    field :brightness_level, :integer
    field :light_intensity, :float
    field :led_temperature, :float
    field :ambient_temperature, :float
    field :humidity, :float
    field :pm25, :float
    field :pm10, :float
    field :rain_level, :float
    field :water_level_cm, :float
    field :noise_db, :float
    field :vibration, :float
    field :tilt_angle, :float
    field :cabinet_open, :boolean, default: false
    field :pedestrian_count, :integer
    field :vehicle_count, :integer
    field :average_vehicle_speed, :float
    field :latitude, :float
    field :longitude, :float
    belongs_to :device, Device

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:recorded_at | @sensor_fields])
    |> validate_required([:device_id, :recorded_at | @sensor_fields])
    |> validate_number(:brightness_level, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:humidity, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:tilt_angle, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_non_negative()
    |> foreign_key_constraint(:device_id)
    |> check_constraint(:brightness_level, name: :telemetry_valid_brightness)
    |> check_constraint(:latitude, name: :telemetry_valid_latitude)
    |> check_constraint(:longitude, name: :telemetry_valid_longitude)
  end

  defp validate_non_negative(changeset) do
    fields = @sensor_fields -- [:cabinet_open, :tilt_angle, :latitude, :longitude]
    Enum.reduce(fields, changeset, &validate_number(&2, &1, greater_than_or_equal_to: 0))
  end
end
