defmodule SmartCityLamp.Monitoring do
  alias SmartCityLamp.Devices.Device

  def summary(devices) do
    %{
      total: length(devices),
      online: count(devices, &(&1.connectivity_status == :online)),
      offline: count(devices, &(&1.connectivity_status == :offline)),
      warning: count(devices, &(marker_status(&1) in [:warning, :suspected])),
      critical: count(devices, &(marker_status(&1) == :critical)),
      maintenance: count(devices, &(&1.status == :maintenance))
    }
  end

  def marker_status(%Device{security_status: :critical}), do: :critical
  def marker_status(%Device{security_status: :suspected_vandalism}), do: :suspected
  def marker_status(%Device{connectivity_status: :offline}), do: :offline
  def marker_status(%Device{status: :maintenance}), do: :maintenance

  def marker_status(%Device{} = device)
      when device.environment_status != :normal or device.traffic_level == :congested or
             device.crowd_level in [:high, :very_high] or device.security_status == :warning,
      do: :warning

  def marker_status(%Device{}), do: :normal

  def map_device(device) do
    %{
      id: device.id,
      device_code: device.device_code,
      name: device.name,
      address: device.installation_address,
      latitude: device.latitude,
      longitude: device.longitude,
      status: marker_status(device),
      lamp_status: device.lamp_status,
      connectivity_status: device.connectivity_status,
      brightness_level: device.brightness_level,
      last_seen_at: device.last_seen_at
    }
  end

  defp count(devices, predicate), do: Enum.count(devices, predicate)
end
