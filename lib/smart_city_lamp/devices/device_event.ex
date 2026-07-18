defmodule SmartCityLamp.Devices.DeviceEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias SmartCityLamp.Devices.Device

  schema "device_events" do
    field :event_type, :string
    field :actor, :string
    field :notes, :string
    field :metadata, :map, default: %{}

    belongs_to :device, Device
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :actor, :notes, :metadata])
    |> validate_required([:device_id, :event_type, :actor])
    |> foreign_key_constraint(:device_id)
  end
end
