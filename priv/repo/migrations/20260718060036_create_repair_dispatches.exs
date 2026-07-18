defmodule SmartCityLamp.Repo.Migrations.CreateRepairDispatches do
  use Ecto.Migration

  def change do
    create table(:repair_dispatches) do
      add :device_id, references(:devices, on_delete: :restrict), null: false
      add :oban_job_id, references(:oban_jobs, on_delete: :nilify_all)
      add :actor, :string, null: false
      add :status, :string, null: false, default: "QUEUED"
      add :origin_latitude, :float, null: false
      add :origin_longitude, :float, null: false
      add :origin_name, :string, null: false
      add :destination_latitude, :float, null: false
      add :destination_longitude, :float, null: false
      add :destination_name, :string, null: false
      add :travel_ms, :integer, null: false
      add :repair_ms, :integer, null: false
      add :en_route_at, :utc_datetime_usec
      add :arrived_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :return_started_at, :utc_datetime_usec
      add :returned_at, :utc_datetime_usec
      add :failed_at, :utc_datetime_usec
      add :failure_reason, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:repair_dispatches, [:device_id])
    create index(:repair_dispatches, [:status, :inserted_at])

    create unique_index(:repair_dispatches, [:device_id],
             where: "status IN ('QUEUED', 'EN_ROUTE', 'REPAIRING')",
             name: :repair_dispatches_one_active_per_device_index
           )
  end
end
