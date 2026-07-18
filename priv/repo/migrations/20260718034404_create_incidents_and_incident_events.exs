defmodule SmartCityLamp.Repo.Migrations.CreateIncidentsAndIncidentEvents do
  use Ecto.Migration

  def change do
    create table(:incidents) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :incident_type, :string, null: false
      add :severity, :string, null: false
      add :status, :string, null: false, default: "OPEN"
      add :confidence_score, :integer, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :detected_signals, {:array, :string}, null: false, default: []
      add :detected_at, :utc_datetime_usec, null: false
      add :acknowledged_at, :utc_datetime_usec
      add :resolved_at, :utc_datetime_usec
      add :assigned_to, :string
      add :resolution_notes, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:incidents, [:device_id])
    create index(:incidents, [:status])
    create index(:incidents, [:severity])
    create index(:incidents, [:detected_at])
    create index(:incidents, [:device_id, :incident_type, :status, :detected_at])

    create constraint(:incidents, :valid_confidence_score,
             check: "confidence_score >= 0 AND confidence_score <= 100"
           )

    create table(:incident_events) do
      add :incident_id, references(:incidents, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :actor, :string, null: false
      add :notes, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:incident_events, [:incident_id])
    create index(:incident_events, [:incident_id, :inserted_at])
  end
end
