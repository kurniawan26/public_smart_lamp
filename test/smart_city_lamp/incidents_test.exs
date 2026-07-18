defmodule SmartCityLamp.IncidentsTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Incidents.Incident
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Telemetry

  setup do
    device =
      Repo.insert!(%Device{
        device_code: "LAMP-INCIDENT-001",
        name: "Incident Device",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Incident Test Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    %{device: device}
  end

  test "telemetry creates an incident with detected audit event and PubSub", %{device: device} do
    Incidents.subscribe()

    assert {:ok, _telemetry, updated_device} =
             Telemetry.ingest(payload(device.device_code, %{"led_temperature" => 95.0}))

    assert updated_device.lamp_status == :overheated
    assert_receive {:incident_created, %Incident{incident_type: :overheat} = incident}
    assert incident.severity == :critical
    assert [%{event_type: "detected", actor: "detection_engine"}] = incident.events
  end

  test "cooldown prevents duplicate incident types", %{device: device} do
    assert {:ok, _, _} =
             Telemetry.ingest(payload(device.device_code, %{"led_temperature" => 95.0}))

    assert {:ok, _, _} =
             Telemetry.ingest(
               payload(device.device_code, %{
                 "led_temperature" => 96.0,
                 "recorded_at" =>
                   DateTime.add(DateTime.utc_now(), 1, :second) |> DateTime.to_iso8601()
               })
             )

    assert Repo.aggregate(from(i in Incident, where: i.incident_type == :overheat), :count) == 1
  end

  test "acknowledge and resolve transitions append audit events", %{device: device} do
    assert {:ok, _, _} =
             Telemetry.ingest(payload(device.device_code, %{"led_temperature" => 95.0}))

    [incident] = Incidents.list_active_incidents()

    assert {:ok, acknowledged} = Incidents.acknowledge(incident.id, "operator@example.com")
    assert acknowledged.status == :acknowledged

    assert {:ok, resolved} =
             Incidents.resolve(incident.id, "operator@example.com", "Cooling assembly replaced")

    assert resolved.status == :resolved

    event_types = resolved.events |> Enum.map(& &1.event_type) |> Enum.sort()
    assert event_types == ["acknowledged", "detected", "resolved"]
    assert Incidents.list_active_incidents() == []
  end

  defp payload(device_code, overrides) do
    Map.merge(
      %{
        "device_code" => device_code,
        "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "voltage" => 220.4,
        "current" => 0.42,
        "power_watt" => 92.5,
        "brightness_level" => 100,
        "light_intensity" => 850.0,
        "led_temperature" => 48.2,
        "ambient_temperature" => 31.5,
        "humidity" => 76.0,
        "pm25" => 22.0,
        "pm10" => 40.0,
        "rain_level" => 0.0,
        "water_level_cm" => 0.0,
        "noise_db" => 62.0,
        "vibration" => 0.03,
        "tilt_angle" => 2.1,
        "cabinet_open" => false,
        "pedestrian_count" => 12,
        "vehicle_count" => 18,
        "average_vehicle_speed" => 35.0,
        "latitude" => -6.2,
        "longitude" => 106.8
      },
      overrides
    )
  end
end
