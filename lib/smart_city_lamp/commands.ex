defmodule SmartCityLamp.Commands do
  import Ecto.Query, warn: false

  require Logger

  alias SmartCityLamp.Commands.DeviceCommand
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Devices.DeviceEvent
  alias SmartCityLamp.Repo

  @command_names %{
    "TURN_ON" => :turn_on,
    "TURN_OFF" => :turn_off,
    "SET_BRIGHTNESS" => :set_brightness,
    "RESTART_DEVICE" => :restart_device,
    "ENTER_MAINTENANCE" => :enter_maintenance,
    "EXIT_MAINTENANCE" => :exit_maintenance
  }
  @command_atoms Map.values(@command_names)

  def command_options, do: Map.keys(@command_names)

  def issue(%Device{} = device, attrs, actor \\ "operator") when is_map(attrs) do
    with {:ok, command_type} <-
           normalize_command(Map.get(attrs, "command_type") || Map.get(attrs, :command_type)),
         {:ok, payload} <-
           normalize_payload(
             command_type,
             Map.get(attrs, "payload") || Map.get(attrs, :payload) || %{}
           ) do
      now = DateTime.utc_now()

      Repo.transaction(fn ->
        command =
          %DeviceCommand{device_id: device.id}
          |> DeviceCommand.request_changeset(%{
            command_type: command_type,
            payload: payload,
            requested_at: now
          })
          |> Repo.insert!()

        device = execute_device_command(device, command_type, payload)

        command =
          command
          |> DeviceCommand.result_changeset(%{
            status: :executed,
            executed_at: now,
            response_message: "Simulator executed #{command_label(command_type)}"
          })
          |> Repo.update!()

        %DeviceEvent{device_id: device.id}
        |> DeviceEvent.changeset(%{
          event_type: "command_executed",
          actor: actor,
          notes: command.response_message,
          metadata: %{
            command_id: command.id,
            command_type: command_label(command_type),
            payload: payload
          }
        })
        |> Repo.insert!()

        {command, device}
      end)
      |> case do
        {:ok, {command, updated_device}} ->
          command = Repo.preload(command, :device)
          broadcast(updated_device, command)

          Logger.info("command executed",
            device_id: updated_device.id,
            device_code: updated_device.device_code,
            event_type: "command_executed",
            command_id: command.id,
            timestamp: DateTime.utc_now()
          )

          {:ok, command, updated_device}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def list_for_device(device_id, limit \\ 20) do
    Repo.all(
      from command in DeviceCommand,
        where: command.device_id == ^device_id,
        order_by: [desc: command.requested_at],
        limit: ^limit
    )
  end

  defp normalize_command(command) when is_atom(command) and command in @command_atoms,
    do: {:ok, command}

  defp normalize_command(command) when is_binary(command) do
    case Map.fetch(@command_names, command) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :unsupported_command}
    end
  end

  defp normalize_command(_command), do: {:error, :unsupported_command}

  defp normalize_payload(:set_brightness, payload) do
    value = Map.get(payload, "brightness_level") || Map.get(payload, :brightness_level)

    case parse_integer(value) do
      brightness when brightness in 0..100 -> {:ok, %{"brightness_level" => brightness}}
      _value -> {:error, :invalid_brightness}
    end
  end

  defp normalize_payload(_command, _payload), do: {:ok, %{}}

  defp execute_device_command(device, :turn_on, _payload) do
    update_device!(device, %{
      brightness_level: max(device.brightness_level, 100),
      lamp_status: :normal
    })
  end

  defp execute_device_command(device, :turn_off, _payload) do
    update_device!(device, %{brightness_level: 0, lamp_status: :dimmed})
  end

  defp execute_device_command(device, :set_brightness, %{"brightness_level" => brightness}) do
    lamp_status = if brightness < 70, do: :dimmed, else: :normal
    update_device!(device, %{brightness_level: brightness, lamp_status: lamp_status})
  end

  defp execute_device_command(device, :restart_device, _payload) do
    update_device!(device, %{connectivity_status: :online, last_seen_at: DateTime.utc_now()})
  end

  defp execute_device_command(device, :enter_maintenance, _payload),
    do: update_device!(device, %{status: :maintenance})

  defp execute_device_command(device, :exit_maintenance, _payload),
    do: update_device!(device, %{status: :active})

  defp update_device!(device, attrs), do: device |> Ecto.Changeset.change(attrs) |> Repo.update!()

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _error -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp command_label(command_type) do
    Enum.find_value(@command_names, fn {label, value} -> if value == command_type, do: label end)
  end

  defp broadcast(device, command) do
    Phoenix.PubSub.broadcast(
      SmartCityLamp.PubSub,
      "device:#{device.id}",
      {:command_executed, command, device}
    )

    Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, "devices", {:device_updated, device})
    Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, "dashboard", {:device_status_updated, device})
  end
end
