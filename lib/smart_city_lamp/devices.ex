defmodule SmartCityLamp.Devices do
  import Ecto.Query, warn: false

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Devices.DeviceEvent
  alias SmartCityLamp.Repo

  def list_devices, do: Repo.all(from device in Device, order_by: [asc: device.device_code])
  def get_device!(id), do: Repo.get!(Device, id)
  def get_device_by_code(code) when is_binary(code), do: Repo.get_by(Device, device_code: code)

  def create_device(attrs) do
    %Device{}
    |> Device.changeset(attrs)
    |> Repo.insert()
  end

  def change_device(%Device{} = device, attrs \\ %{}), do: Device.changeset(device, attrs)

  def set_simulated_offline(%Device{} = device) do
    device
    |> Ecto.Changeset.change(
      connectivity_status: :offline,
      lamp_status: :offline,
      brightness_level: 0
    )
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, "devices", {:device_updated, updated})

        Phoenix.PubSub.broadcast(
          SmartCityLamp.PubSub,
          "device:#{updated.id}",
          {:device_status_updated, updated}
        )

        Phoenix.PubSub.broadcast(
          SmartCityLamp.PubSub,
          "dashboard",
          {:device_status_updated, updated}
        )

        {:ok, updated}

      error ->
        error
    end
  end

  def recover_simulated_device(%Device{} = device, actor) do
    device
    |> Ecto.Changeset.change(
      connectivity_status: :online,
      lamp_status: :normal,
      security_status: :safe,
      environment_status: :normal,
      crowd_level: :low,
      traffic_level: :low,
      brightness_level: 100,
      last_seen_at: DateTime.utc_now()
    )
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        _ =
          record_event(updated, %{
            event_type: "admin_device_recovery",
            actor: actor,
            notes: "Device recovered by administrator",
            metadata: %{source: "admin_device_detail"}
          })

        Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, "devices", {:device_updated, updated})

        Phoenix.PubSub.broadcast(
          SmartCityLamp.PubSub,
          "device:#{updated.id}",
          {:device_status_updated, updated}
        )

        Phoenix.PubSub.broadcast(
          SmartCityLamp.PubSub,
          "dashboard",
          {:device_status_updated, updated}
        )

        {:ok, updated}

      error ->
        error
    end
  end

  def list_events(device_id, limit \\ 50) do
    Repo.all(
      from event in DeviceEvent,
        where: event.device_id == ^device_id,
        order_by: [desc: event.inserted_at],
        limit: ^limit
    )
  end

  def record_event(%Device{} = device, attrs) do
    %DeviceEvent{device_id: device.id}
    |> DeviceEvent.changeset(attrs)
    |> Repo.insert()
  end
end
