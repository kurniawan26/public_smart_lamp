defmodule SmartCityLamp.Repo.Migrations.CreateTelemetryRecords do
  use Ecto.Migration

  def change do
    create table(:telemetry_records) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :recorded_at, :utc_datetime_usec, null: false
      add :voltage, :float, null: false
      add :current, :float, null: false
      add :power_watt, :float, null: false
      add :brightness_level, :integer, null: false
      add :light_intensity, :float, null: false
      add :led_temperature, :float, null: false
      add :ambient_temperature, :float, null: false
      add :humidity, :float, null: false
      add :pm25, :float, null: false
      add :pm10, :float, null: false
      add :rain_level, :float, null: false
      add :water_level_cm, :float, null: false
      add :noise_db, :float, null: false
      add :vibration, :float, null: false
      add :tilt_angle, :float, null: false
      add :cabinet_open, :boolean, null: false, default: false
      add :pedestrian_count, :integer, null: false
      add :vehicle_count, :integer, null: false
      add :average_vehicle_speed, :float, null: false
      add :latitude, :float, null: false
      add :longitude, :float, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:telemetry_records, [:device_id])
    create index(:telemetry_records, [:recorded_at])
    create index(:telemetry_records, [:device_id, :recorded_at])

    create constraint(:telemetry_records, :telemetry_valid_brightness,
             check: "brightness_level >= 0 AND brightness_level <= 100"
           )

    create constraint(:telemetry_records, :telemetry_valid_latitude,
             check: "latitude >= -90 AND latitude <= 90"
           )

    create constraint(:telemetry_records, :telemetry_valid_longitude,
             check: "longitude >= -180 AND longitude <= 180"
           )
  end
end
