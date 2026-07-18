defmodule SmartCityLamp.Simulations.LiveSensorBroadcaster do
  use GenServer

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Devices.Device

  @topic "live_sensors"

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def subscribe, do: Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, @topic)
  def latest(device_id), do: GenServer.call(__MODULE__, {:latest, device_id})

  def broadcast_device(%Device{} = device),
    do: GenServer.call(__MODULE__, {:broadcast_device, device})

  @impl true
  def init(_opts) do
    interval = Application.get_env(:smart_city_lamp, :live_sensor_interval_ms, 3_000)
    if is_integer(interval), do: Process.send_after(self(), :tick, interval)
    {:ok, %{interval: interval, readings: %{}}}
  end

  @impl true
  def handle_call({:latest, device_id}, _from, state),
    do: {:reply, Map.get(state.readings, device_id), state}

  def handle_call({:broadcast_device, device}, _from, state) do
    {reply, state} = maybe_broadcast(device, state)
    {:reply, reply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    state =
      Enum.reduce(Devices.list_devices(), state, fn device, acc ->
        elem(maybe_broadcast(device, acc), 1)
      end)

    Process.send_after(self(), :tick, state.interval)
    {:noreply, state}
  end

  defp maybe_broadcast(%Device{} = device, state) do
    if transmitting?(device) do
      reading = random_reading(device)

      Phoenix.PubSub.broadcast(
        SmartCityLamp.PubSub,
        @topic,
        {:live_sensor_reading, device.id, reading}
      )

      Phoenix.PubSub.broadcast(
        SmartCityLamp.PubSub,
        "device:#{device.id}",
        {:live_sensor_reading, device.id, reading}
      )

      {:ok, put_in(state, [:readings, device.id], reading)}
    else
      {:skipped, update_in(state.readings, &Map.delete(&1, device.id))}
    end
  end

  defp transmitting?(device) do
    device.connectivity_status != :offline and
      device.lamp_status not in [:offline, :power_failure]
  end

  defp random_reading(device) do
    humidity = random_float(58, 98)
    rain = if humidity > 88, do: random_float(45, 100), else: random_float(0, 25)
    water = if rain > 75, do: random_float(12, 52), else: random_float(0, 8)
    pm25 = random_float(8, 180)
    noise = random_float(48, 98)
    pedestrians = :rand.uniform(100) - 1
    vehicles = :rand.uniform(95) - 1
    speed = if vehicles > 70, do: random_float(4, 18), else: random_float(20, 55)

    %{
      id: System.unique_integer([:positive, :monotonic]),
      device_id: device.id,
      device_code: device.device_code,
      recorded_at: DateTime.utc_now(),
      ambient_temperature: random_float(27, 42),
      humidity: humidity,
      pm25: pm25,
      pm10: Float.round(pm25 * random_float(1.2, 1.65), 1),
      rain_level: rain,
      water_level_cm: water,
      noise_db: noise,
      pedestrian_count: pedestrians,
      vehicle_count: vehicles,
      average_vehicle_speed: speed,
      weather: weather(rain, water),
      air_quality: air_quality(pm25),
      noise_level: if(noise > 85, do: :high, else: :normal),
      crowd_level: crowd_level(pedestrians),
      traffic_level: traffic_level(vehicles, speed)
    }
  end

  defp weather(_rain, water) when water > 40, do: :flood_risk
  defp weather(_rain, water) when water > 20, do: :flood_warning
  defp weather(rain, _water) when rain > 60, do: :heavy_rain
  defp weather(_rain, _water), do: :normal

  defp air_quality(pm25) when pm25 > 150, do: :unhealthy
  defp air_quality(pm25) when pm25 > 55, do: :poor
  defp air_quality(_pm25), do: :normal

  defp crowd_level(count) when count > 70, do: :very_high
  defp crowd_level(count) when count > 30, do: :high
  defp crowd_level(count) when count > 10, do: :medium
  defp crowd_level(_count), do: :low

  defp traffic_level(count, speed) when count > 70 and speed < 20, do: :congested
  defp traffic_level(count, _speed) when count > 50, do: :high
  defp traffic_level(count, _speed) when count > 20, do: :medium
  defp traffic_level(_count, _speed), do: :low

  defp random_float(min, max), do: Float.round(min + :rand.uniform() * (max - min), 1)
end
