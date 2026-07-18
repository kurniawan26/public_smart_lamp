defmodule SmartCityLamp.DevicesTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Devices.Device

  @valid_attrs %{
    device_code: "LAMP-TEST-001",
    name: "Test Device",
    latitude: -6.2,
    longitude: 106.8,
    installation_address: "Jakarta Test Area",
    installation_date: ~D[2026-01-01],
    firmware_version: "1.0.0"
  }

  test "device changeset accepts valid attributes and enum values" do
    changeset = Device.changeset(%Device{}, Map.put(@valid_attrs, :status, :maintenance))

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :status) == :maintenance
  end

  test "device changeset validates coordinates and brightness" do
    changeset =
      Device.changeset(
        %Device{},
        @valid_attrs
        |> Map.put(:latitude, 91)
        |> Map.put(:longitude, -181)
        |> Map.put(:brightness_level, 101)
      )

    refute changeset.valid?
    assert "must be less than or equal to 90" in errors_on(changeset).latitude
    assert "must be greater than or equal to -180" in errors_on(changeset).longitude
    assert "must be less than or equal to 100" in errors_on(changeset).brightness_level
  end

  test "device_code is unique" do
    assert {:ok, _device} = Devices.create_device(@valid_attrs)
    assert {:error, changeset} = Devices.create_device(@valid_attrs)
    assert "has already been taken" in errors_on(changeset).device_code
  end
end
