defmodule SmartCityLamp.Simulations do
  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Devices
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Simulations.RateLimiter
  alias SmartCityLamp.Telemetry

  @public_events %{
    "HIT_LAMP" => :hit_lamp,
    "OPEN_CABINET" => :open_cabinet,
    "DISCONNECT_POWER" => :disconnect_power,
    "TILT_LAMP" => :tilt_lamp,
    "MOVE_DEVICE" => :move_device,
    "DEVICE_OFFLINE" => :device_offline
  }

  @telemetry_fields ~w(voltage current power_watt brightness_level light_intensity led_temperature ambient_temperature humidity pm25 pm10 rain_level water_level_cm noise_db vibration tilt_angle cabinet_open pedestrian_count vehicle_count average_vehicle_speed latitude longitude)a

  @scenarios [
    {"Normal Operation", "normal"},
    {"Hit Lamp", "hit_lamp"},
    {"Open Cabinet", "open_cabinet"},
    {"Disconnect Power", "disconnect_power"},
    {"Tilt Lamp", "tilt_lamp"},
    {"Move Device", "move_device"},
    {"Device Offline", "device_offline"},
    {"Overheat", "overheat"},
    {"Heavy Rain", "heavy_rain"},
    {"Flood Risk", "flood_risk"},
    {"Poor Air Quality", "poor_air_quality"},
    {"High Crowd", "high_crowd"},
    {"Traffic Congestion", "traffic_congestion"},
    {"Recover Device", "recover_device"}
  ]

  @auto_modes ~w(NORMAL RANDOM VANDALISM_SEQUENCE ENVIRONMENT_ALERT TRAFFIC_SURGE)

  def scenarios, do: @scenarios
  def auto_modes, do: @auto_modes
  def public_events, do: @public_events

  def parse_public_event(event) when is_binary(event), do: Map.fetch(@public_events, event)
  def parse_public_event(_event), do: :error

  def run_scenario(%Device{} = device, event, opts \\ []) do
    with {:ok, event} <- normalize_event(event),
         :ok <- check_limit(opts[:rate_key], device.id) do
      execute_scenario(device, event)
    end
  end

  def recover_device(%Device{} = device, actor) when is_binary(actor) do
    with {:ok, result} <- execute_scenario(device, :recover_device),
         {:ok, recovered_device} <- Devices.recover_simulated_device(result.device, actor) do
      {:ok, %{result | device: recovered_device}}
    end
  end

  defp execute_scenario(device, event) do
    previous_incident_ids = device.id |> Incidents.list_for_device() |> MapSet.new(& &1.id)

    payload =
      device
      |> latest_payload()
      |> apply_scenario(event_to_scenario(event))
      |> touch()

    with {:ok, telemetry, updated_device} <- Telemetry.ingest(payload),
         {:ok, updated_device} <- maybe_mark_offline(updated_device, event) do
      incident_created =
        updated_device.id
        |> Incidents.list_for_device()
        |> Enum.any?(&(not MapSet.member?(previous_incident_ids, &1.id)))

      {:ok,
       %{
         event: event,
         telemetry: telemetry,
         device: updated_device,
         incident_created: incident_created
       }}
    end
  end

  defp normalize_event(event) when is_atom(event) do
    if event in Map.values(@public_events),
      do: {:ok, event},
      else: {:error, :invalid_simulation_event}
  end

  defp normalize_event(event) when is_binary(event) do
    case parse_public_event(event) do
      {:ok, parsed} -> {:ok, parsed}
      :error -> {:error, :invalid_simulation_event}
    end
  end

  defp normalize_event(_event), do: {:error, :invalid_simulation_event}

  defp check_limit(nil, _device_id), do: :ok
  defp check_limit(rate_key, device_id), do: RateLimiter.check(rate_key, device_id)

  defp maybe_mark_offline(device, :device_offline), do: Devices.set_simulated_offline(device)
  defp maybe_mark_offline(device, _event), do: {:ok, device}

  defp latest_payload(device) do
    case Telemetry.latest_for_device(device.id) do
      nil ->
        baseline(device)

      telemetry ->
        Enum.reduce(@telemetry_fields, baseline(device), fn field, payload ->
          Map.put(payload, Atom.to_string(field), Map.get(telemetry, field))
        end)
    end
  end

  defp event_to_scenario(:normal_operation), do: "normal"
  defp event_to_scenario(event), do: Atom.to_string(event)

  def baseline(%Device{} = device) do
    %{
      "device_code" => device.device_code,
      "recorded_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      "voltage" => 220.4,
      "current" => 0.42,
      "power_watt" => 92.5,
      "brightness_level" => device.brightness_level,
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
      "latitude" => device.latitude,
      "longitude" => device.longitude
    }
  end

  def apply_scenario(payload, "normal"), do: recover(payload)
  def apply_scenario(payload, "recover_device"), do: recover(payload)
  def apply_scenario(payload, "hit_lamp"), do: Map.put(payload, "vibration", 0.92)
  def apply_scenario(payload, "open_cabinet"), do: Map.put(payload, "cabinet_open", true)

  def apply_scenario(payload, "disconnect_power") do
    Map.merge(payload, %{"current" => 0.0, "power_watt" => 0.0, "light_intensity" => 0.0})
  end

  def apply_scenario(payload, "tilt_lamp"), do: Map.put(payload, "tilt_angle", 25.0)

  def apply_scenario(payload, "move_device") do
    payload
    |> Map.update!("latitude", &(number(&1) + 0.0004))
    |> Map.update!("longitude", &(number(&1) + 0.0004))
  end

  def apply_scenario(payload, "device_offline") do
    Map.merge(payload, %{
      "current" => 0.0,
      "power_watt" => 0.0,
      "light_intensity" => 0.0,
      "brightness_level" => 0
    })
  end

  def apply_scenario(payload, "overheat"), do: Map.put(payload, "led_temperature", 95.0)

  def apply_scenario(payload, "heavy_rain") do
    Map.merge(payload, %{"rain_level" => 85.0, "humidity" => 94.0})
  end

  def apply_scenario(payload, "flood_risk") do
    Map.merge(payload, %{"rain_level" => 95.0, "humidity" => 97.0, "water_level_cm" => 45.0})
  end

  def apply_scenario(payload, "poor_air_quality"),
    do: Map.merge(payload, %{"pm25" => 168.0, "pm10" => 220.0})

  def apply_scenario(payload, "high_crowd"), do: Map.put(payload, "pedestrian_count", 96)

  def apply_scenario(payload, "traffic_congestion") do
    Map.merge(payload, %{"vehicle_count" => 88, "average_vehicle_speed" => 7.0})
  end

  def apply_scenario(payload, _unknown), do: payload

  def next_payload(payload, "NORMAL"), do: jitter(recover(payload))

  def next_payload(payload, "RANDOM"),
    do: payload |> recover() |> apply_scenario(random_scenario()) |> jitter()

  def next_payload(payload, "VANDALISM_SEQUENCE"), do: vandalism_step(payload)

  def next_payload(payload, "ENVIRONMENT_ALERT"),
    do:
      payload
      |> recover()
      |> apply_scenario(Enum.random(~w(heavy_rain flood_risk poor_air_quality)))

  def next_payload(payload, "TRAFFIC_SURGE"),
    do: payload |> recover() |> apply_scenario("traffic_congestion")

  def next_payload(payload, _mode), do: jitter(payload)

  def interval_ms("NORMAL"), do: 10_000
  def interval_ms("RANDOM"), do: 5_000
  def interval_ms(_mode), do: 3_000

  def touch(payload),
    do: Map.put(payload, "recorded_at", DateTime.utc_now() |> DateTime.to_iso8601())

  defp recover(payload) do
    Map.merge(payload, %{
      "voltage" => 220.4,
      "current" => 0.42,
      "power_watt" => 92.5,
      "brightness_level" => 100,
      "light_intensity" => 850.0,
      "led_temperature" => 48.2,
      "humidity" => 76.0,
      "pm25" => 22.0,
      "pm10" => 40.0,
      "rain_level" => 0.0,
      "water_level_cm" => 0.0,
      "vibration" => 0.03,
      "tilt_angle" => 2.1,
      "cabinet_open" => false,
      "pedestrian_count" => 12,
      "vehicle_count" => 18,
      "average_vehicle_speed" => 35.0
    })
  end

  defp jitter(payload) do
    Map.merge(payload, %{
      "voltage" => Float.round(219.5 + :rand.uniform() * 2.0, 2),
      "ambient_temperature" => Float.round(30.0 + :rand.uniform() * 3.0, 1),
      "pedestrian_count" => 8 + :rand.uniform(15),
      "vehicle_count" => 12 + :rand.uniform(15)
    })
  end

  defp vandalism_step(payload) do
    cond do
      number(payload["vibration"]) < 0.8 -> apply_scenario(payload, "hit_lamp")
      payload["cabinet_open"] not in [true, "true"] -> apply_scenario(payload, "open_cabinet")
      number(payload["current"]) > 0.01 -> apply_scenario(payload, "disconnect_power")
      true -> payload
    end
  end

  defp random_scenario,
    do:
      Enum.random(
        ~w(normal hit_lamp open_cabinet overheat heavy_rain poor_air_quality high_crowd traffic_congestion)
      )

  defp number(value) when is_number(value), do: value
  defp number(value) when is_binary(value), do: elem(Float.parse(value), 0)
end
