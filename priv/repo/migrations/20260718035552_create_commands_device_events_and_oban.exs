defmodule SmartCityLamp.Repo.Migrations.CreateCommandsDeviceEventsAndOban do
  use Ecto.Migration

  def up do
    Oban.Migration.up()

    create table(:device_commands) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :command_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :status, :string, null: false, default: "PENDING"
      add :requested_at, :utc_datetime_usec, null: false
      add :executed_at, :utc_datetime_usec
      add :failed_at, :utc_datetime_usec
      add :response_message, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:device_commands, [:device_id])
    create index(:device_commands, [:status])
    create index(:device_commands, [:device_id, :requested_at])

    create table(:device_events) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :actor, :string, null: false
      add :notes, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:device_events, [:device_id])
    create index(:device_events, [:device_id, :inserted_at])
  end

  def down do
    drop table(:device_events)
    drop table(:device_commands)

    Oban.Migration.down()
  end
end
