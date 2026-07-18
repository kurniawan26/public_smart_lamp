defmodule SmartCityLampWeb.DeviceSimulatorLive do
  use SmartCityLampWeb, :live_view

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Simulations
  alias SmartCityLamp.Telemetry

  @impl true
  def mount(_params, _session, socket) do
    devices = Devices.list_devices()
    selected_device = List.first(devices)
    payload = if selected_device, do: Simulations.baseline(selected_device), else: %{}

    {:ok,
     socket
     |> assign(:page_title, "Device Simulator")
     |> assign(:devices, devices)
     |> assign(:selected_device, selected_device)
     |> assign(:payload, payload)
     |> assign(:form, to_form(payload, as: :telemetry))
     |> assign(:auto_form, to_form(%{"mode" => "NORMAL"}, as: :auto))
     |> assign(:auto_mode, "NORMAL")
     |> assign(:auto_enabled, false)
     |> assign(:timer_ref, nil)
     |> assign(:latest_telemetry, latest(selected_device))}
  end

  @impl true
  def handle_event("validate", %{"telemetry" => params}, socket) do
    selected_code = socket.assigns.selected_device && socket.assigns.selected_device.device_code

    if params["device_code"] != selected_code do
      device = Devices.get_device_by_code(params["device_code"])
      payload = if device, do: Simulations.baseline(device), else: params

      {:noreply,
       socket
       |> assign(:selected_device, device)
       |> assign(:latest_telemetry, latest(device))
       |> put_payload(payload)}
    else
      {:noreply, put_payload(socket, Map.put_new(params, "cabinet_open", "false"))}
    end
  end

  def handle_event("scenario", %{"scenario" => scenario}, socket) do
    payload =
      socket.assigns.payload |> Simulations.apply_scenario(scenario) |> Simulations.touch()

    {:noreply, put_payload(socket, payload)}
  end

  def handle_event("send_telemetry", %{"telemetry" => params}, socket) do
    payload = params |> Map.put_new("cabinet_open", "false") |> Simulations.touch()

    case Telemetry.ingest(payload) do
      {:ok, telemetry, device} ->
        {:noreply,
         socket
         |> assign(:selected_device, device)
         |> assign(:latest_telemetry, telemetry)
         |> put_payload(payload)
         |> put_flash(:info, "Telemetry sent and broadcast to the dashboard")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :telemetry))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Telemetry rejected: #{reason}")}
    end
  end

  def handle_event("set_auto_mode", %{"auto" => %{"mode" => mode}}, socket) do
    if mode in Simulations.auto_modes() do
      {:noreply,
       socket
       |> assign(:auto_mode, mode)
       |> assign(:auto_form, to_form(%{"mode" => mode}, as: :auto))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_auto", _params, %{assigns: %{auto_enabled: true}} = socket) do
    cancel_timer(socket.assigns.timer_ref)
    {:noreply, socket |> assign(:auto_enabled, false) |> assign(:timer_ref, nil)}
  end

  def handle_event("toggle_auto", _params, socket) do
    {:noreply, socket |> assign(:auto_enabled, true) |> schedule_tick()}
  end

  @impl true
  def handle_info(:auto_tick, %{assigns: %{auto_enabled: true}} = socket) do
    payload =
      socket.assigns.payload
      |> Simulations.next_payload(socket.assigns.auto_mode)
      |> Simulations.touch()

    socket =
      case Telemetry.ingest(payload) do
        {:ok, telemetry, device} ->
          socket
          |> assign(:selected_device, device)
          |> assign(:latest_telemetry, telemetry)
          |> put_payload(payload)

        {:error, _reason} ->
          put_flash(socket, :error, "Auto telemetry was rejected")
      end

    {:noreply, schedule_tick(socket)}
  end

  def handle_info(:auto_tick, socket), do: {:noreply, socket}

  def sensor_fields do
    [
      {:voltage, "Voltage", "number", "0.1"},
      {:current, "Current", "number", "0.01"},
      {:power_watt, "Power (W)", "number", "0.1"},
      {:brightness_level, "Brightness", "number", "1"},
      {:light_intensity, "Light intensity", "number", "1"},
      {:led_temperature, "LED temperature", "number", "0.1"},
      {:ambient_temperature, "Ambient temperature", "number", "0.1"},
      {:humidity, "Humidity", "number", "0.1"},
      {:pm25, "PM2.5", "number", "0.1"},
      {:pm10, "PM10", "number", "0.1"},
      {:rain_level, "Rain level", "number", "0.1"},
      {:water_level_cm, "Water level", "number", "0.1"},
      {:noise_db, "Noise dB", "number", "0.1"},
      {:vibration, "Vibration", "number", "0.01"},
      {:tilt_angle, "Tilt angle", "number", "0.1"},
      {:pedestrian_count, "Pedestrians", "number", "1"},
      {:vehicle_count, "Vehicles", "number", "1"},
      {:average_vehicle_speed, "Average speed", "number", "0.1"},
      {:latitude, "Latitude", "number", "0.000001"},
      {:longitude, "Longitude", "number", "0.000001"}
    ]
  end

  attr :label, :string, required: true
  attr :value, :string, required: true

  def reading(assigns) do
    ~H"""
    <div class="rounded-xl bg-slate-100/80 p-3">
      <span class="block text-[9px] font-bold uppercase tracking-wider text-slate-600">{@label}</span>
      <strong class="mt-1 block text-xs text-slate-900">{@value}</strong>
    </div>
    """
  end

  defp put_payload(socket, payload) do
    socket
    |> assign(:payload, payload)
    |> assign(:form, to_form(payload, as: :telemetry))
  end

  defp latest(nil), do: nil
  defp latest(device), do: Telemetry.latest_for_device(device.id)

  defp schedule_tick(socket) do
    ref =
      Process.send_after(self(), :auto_tick, Simulations.interval_ms(socket.assigns.auto_mode))

    assign(socket, :timer_ref, ref)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(ref), do: Process.cancel_timer(ref)
end
