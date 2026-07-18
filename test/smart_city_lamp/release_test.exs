defmodule SmartCityLamp.ReleaseTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Accounts.Admin
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Release
  alias SmartCityLamp.Repo

  test "demo initialization is idempotent" do
    assert :ok = Release.seed_demo()
    assert Repo.aggregate(Device, :count) == 20
    assert Repo.aggregate(Admin, :count) == 1

    assert :ok = Release.seed_demo()
    assert Repo.aggregate(Device, :count) == 20
    assert Repo.aggregate(Admin, :count) == 1
  end
end
