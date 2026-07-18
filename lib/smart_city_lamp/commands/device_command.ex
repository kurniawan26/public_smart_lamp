defmodule SmartCityLamp.Commands.DeviceCommand do
  use Ecto.Schema
  import Ecto.Changeset

  alias SmartCityLamp.Devices.Device

  @command_types [
    turn_on: "TURN_ON",
    turn_off: "TURN_OFF",
    set_brightness: "SET_BRIGHTNESS",
    restart_device: "RESTART_DEVICE",
    enter_maintenance: "ENTER_MAINTENANCE",
    exit_maintenance: "EXIT_MAINTENANCE"
  ]
  @statuses [pending: "PENDING", executed: "EXECUTED", failed: "FAILED"]

  schema "device_commands" do
    field :command_type, Ecto.Enum, values: @command_types
    field :payload, :map, default: %{}
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :requested_at, :utc_datetime_usec
    field :executed_at, :utc_datetime_usec
    field :failed_at, :utc_datetime_usec
    field :response_message, :string

    belongs_to :device, Device
    timestamps(type: :utc_datetime_usec)
  end

  def request_changeset(command, attrs) do
    command
    |> cast(attrs, [:command_type, :payload, :requested_at])
    |> validate_required([:device_id, :command_type, :status, :requested_at])
    |> foreign_key_constraint(:device_id)
  end

  def result_changeset(command, attrs) do
    command
    |> cast(attrs, [:status, :executed_at, :failed_at, :response_message])
    |> validate_required([:status])
  end
end
