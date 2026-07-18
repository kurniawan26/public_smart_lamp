defmodule SmartCityLamp.CommandsTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Commands
  alias SmartCityLamp.Commands.DeviceCommand
  alias SmartCityLamp.Devices
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repo

  setup do
    device =
      Repo.insert!(%Device{
        device_code: "LAMP-COMMAND-001",
        name: "Command Device",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Command Test Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    %{device: device}
  end

  test "SET_BRIGHTNESS executes, audits, and broadcasts", %{device: device} do
    Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, "device:#{device.id}")

    assert {:ok, %DeviceCommand{status: :executed} = command, updated_device} =
             Commands.issue(device, %{
               "command_type" => "SET_BRIGHTNESS",
               "payload" => %{"brightness_level" => 50}
             })

    assert updated_device.brightness_level == 50
    assert updated_device.lamp_status == :dimmed
    assert_receive {:command_executed, ^command, ^updated_device}

    assert [%{event_type: "command_executed", metadata: metadata}] =
             Devices.list_events(device.id)

    assert metadata["command_id"] == command.id
  end

  test "maintenance commands change device mode", %{device: device} do
    assert {:ok, _, maintenance_device} =
             Commands.issue(device, %{"command_type" => "ENTER_MAINTENANCE"})

    assert maintenance_device.status == :maintenance

    assert {:ok, _, active_device} =
             Commands.issue(maintenance_device, %{"command_type" => "EXIT_MAINTENANCE"})

    assert active_device.status == :active
  end

  test "invalid brightness is rejected without persistence", %{device: device} do
    assert {:error, :invalid_brightness} =
             Commands.issue(device, %{
               "command_type" => "SET_BRIGHTNESS",
               "payload" => %{"brightness_level" => 120}
             })

    assert Repo.aggregate(DeviceCommand, :count) == 0
  end
end
