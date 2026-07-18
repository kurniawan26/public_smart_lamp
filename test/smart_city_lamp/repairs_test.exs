defmodule SmartCityLamp.RepairsTest do
  use SmartCityLamp.DataCase
  use Oban.Testing, repo: SmartCityLamp.Repo

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repairs
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Workers.RepairWorker

  test "a batch continues from the prior lamp and returns to office only when empty" do
    first = offline_device("LAMP-BATCH-001", -6.20, 106.81)
    second = offline_device("LAMP-BATCH-002", -6.22, 106.84)
    Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, "repairs")

    assert {:ok, first_dispatch} = Repairs.dispatch(first, "admin@test.local")
    assert {:ok, second_dispatch} = Repairs.dispatch(second, "admin@test.local")

    assert second_dispatch.origin.latitude == first.latitude
    assert second_dispatch.origin.longitude == first.longitude

    assert :ok = perform_job(RepairWorker, %{dispatch_id: first_dispatch.id})
    refute_receive {:technician_returning, _route}

    assert :ok = perform_job(RepairWorker, %{dispatch_id: second_dispatch.id})

    assert_receive {:technician_returning, route}
    assert route.origin.latitude == second.latitude
    assert route.destination.latitude == Repairs.office().latitude
    assert_receive {:technician_returned, _route}
  end

  defp offline_device(code, latitude, longitude) do
    Repo.insert!(%Device{
      device_code: code,
      name: code,
      latitude: latitude,
      longitude: longitude,
      installation_address: "Batch route",
      installation_date: ~D[2026-01-01],
      firmware_version: "1.0.0",
      connectivity_status: :offline,
      lamp_status: :offline,
      brightness_level: 0
    })
  end
end
