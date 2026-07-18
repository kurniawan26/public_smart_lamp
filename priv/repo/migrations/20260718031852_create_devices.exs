defmodule SmartCityLamp.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :device_code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :latitude, :float, null: false
      add :longitude, :float, null: false
      add :installation_address, :string, null: false
      add :installation_date, :date, null: false
      add :status, :string, null: false, default: "ACTIVE"
      add :lamp_status, :string, null: false, default: "NORMAL"
      add :security_status, :string, null: false, default: "SAFE"
      add :environment_status, :string, null: false, default: "NORMAL"
      add :crowd_level, :string, null: false, default: "LOW"
      add :traffic_level, :string, null: false, default: "LOW"
      add :connectivity_status, :string, null: false, default: "ONLINE"
      add :brightness_level, :integer, null: false, default: 100
      add :firmware_version, :string, null: false
      add :last_seen_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:devices, [:device_code])
    create index(:devices, [:status])
    create index(:devices, [:connectivity_status])
    create index(:devices, [:security_status])
    create index(:devices, [:latitude, :longitude])
    create constraint(:devices, :valid_latitude, check: "latitude >= -90 AND latitude <= 90")
    create constraint(:devices, :valid_longitude, check: "longitude >= -180 AND longitude <= 180")

    create constraint(:devices, :valid_brightness,
             check: "brightness_level >= 0 AND brightness_level <= 100"
           )
  end
end
