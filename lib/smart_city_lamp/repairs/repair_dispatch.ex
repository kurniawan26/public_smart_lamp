defmodule SmartCityLamp.Repairs.RepairDispatch do
  use Ecto.Schema
  import Ecto.Changeset

  alias SmartCityLamp.Devices.Device

  @statuses [
    queued: "QUEUED",
    en_route: "EN_ROUTE",
    repairing: "REPAIRING",
    completed: "COMPLETED",
    returning: "RETURNING",
    returned: "RETURNED",
    failed: "FAILED"
  ]

  schema "repair_dispatches" do
    field :actor, :string
    field :status, Ecto.Enum, values: @statuses, default: :queued
    field :origin_latitude, :float
    field :origin_longitude, :float
    field :origin_name, :string
    field :destination_latitude, :float
    field :destination_longitude, :float
    field :destination_name, :string
    field :travel_ms, :integer
    field :repair_ms, :integer
    field :en_route_at, :utc_datetime_usec
    field :arrived_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :return_started_at, :utc_datetime_usec
    field :returned_at, :utc_datetime_usec
    field :failed_at, :utc_datetime_usec
    field :failure_reason, :string
    field :oban_job_id, :integer

    belongs_to :device, Device
    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(dispatch, attrs) do
    dispatch
    |> cast(attrs, [
      :actor,
      :origin_latitude,
      :origin_longitude,
      :origin_name,
      :destination_latitude,
      :destination_longitude,
      :destination_name,
      :travel_ms,
      :repair_ms
    ])
    |> validate_required([
      :device_id,
      :actor,
      :origin_latitude,
      :origin_longitude,
      :origin_name,
      :destination_latitude,
      :destination_longitude,
      :destination_name,
      :travel_ms,
      :repair_ms
    ])
    |> validate_number(:travel_ms, greater_than_or_equal_to: 0)
    |> validate_number(:repair_ms, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:device_id)
    |> unique_constraint(:device_id,
      name: :repair_dispatches_one_active_per_device_index
    )
  end

  def state_changeset(dispatch, attrs) do
    cast(dispatch, attrs, [
      :status,
      :oban_job_id,
      :en_route_at,
      :arrived_at,
      :completed_at,
      :return_started_at,
      :returned_at,
      :failed_at,
      :failure_reason
    ])
  end
end
