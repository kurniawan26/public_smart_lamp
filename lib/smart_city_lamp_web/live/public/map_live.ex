defmodule SmartCityLampWeb.Public.MapLive do
  use SmartCityLampWeb, :live_view

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Monitoring
  alias SmartCityLamp.Repairs
  alias SmartCityLamp.Simulations
  alias SmartCityLamp.Simulations.LiveSensorBroadcaster
  alias SmartCityLamp.Telemetry

  @scenarios [
    {"Hit Lamp", "HIT_LAMP", "hero-bolt"},
    {"Open Cabinet", "OPEN_CABINET", "hero-lock-open"},
    {"Disconnect Power", "DISCONNECT_POWER", "hero-power"},
    {"Tilt Lamp", "TILT_LAMP", "hero-arrows-right-left"},
    {"Move Device", "MOVE_DEVICE", "hero-map-pin"},
    {"Device Offline", "DEVICE_OFFLINE", "hero-signal-slash"}
  ]

  def mount(_params, session, socket) do
    if connected?(socket) do
      Telemetry.subscribe_dashboard()
      LiveSensorBroadcaster.subscribe()
      Repairs.subscribe()
    end

    {:ok,
     socket
     |> assign(:page_title, "Public Lamp Map")
     |> assign(:selected_device, nil)
     |> assign(:latest_telemetry, nil)
     |> assign(:live_reading, nil)
     |> assign(:active_repair, List.first(Repairs.list_active()))
     |> assign(:last_result, nil)
     |> assign(
       :simulation_enabled,
       Application.get_env(:smart_city_lamp, :enable_public_emulator, false)
     )
     |> assign(:rate_key, "live:" <> Map.fetch!(session, "simulator_session_id"))
     |> refresh()}
  end

  def handle_event("select_device", %{"id" => id}, socket) do
    case Devices.get_device!(id) do
      device ->
        {:noreply,
         assign(socket,
           selected_device: device,
           latest_telemetry: Telemetry.latest_for_device(device.id),
           live_reading: LiveSensorBroadcaster.latest(device.id),
           last_result: nil
         )}
    end
  rescue
    Ecto.NoResultsError -> {:noreply, put_flash(socket, :error, "Unknown device")}
  end

  def handle_event("close_device", _params, socket),
    do: {:noreply, assign(socket, :selected_device, nil)}

  def handle_event(
        "run_scenario",
        %{"event" => event},
        %{assigns: %{simulation_enabled: true, selected_device: device}} = socket
      )
      when not is_nil(device) do
    case Simulations.run_scenario(device, event, rate_key: socket.assigns.rate_key) do
      {:ok, result} ->
        {:noreply,
         assign(socket,
           selected_device: result.device,
           latest_telemetry: result.telemetry,
           last_result: result
         )}

      {:error, :device_cooldown} ->
        {:noreply, put_flash(socket, :error, "Please wait two seconds before the next event.")}

      {:error, :rate_limit_exceeded} ->
        {:noreply, put_flash(socket, :error, "Session limit reached. Try again in one minute.")}

      {:error, :invalid_simulation_event} ->
        {:noreply, put_flash(socket, :error, "Unsupported simulation event.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The simulation could not be processed.")}
    end
  end

  def handle_event("run_scenario", _params, socket), do: {:noreply, socket}

  def handle_info({:dashboard_updated, device, telemetry}, socket) do
    socket =
      if socket.assigns.selected_device && socket.assigns.selected_device.id == device.id,
        do:
          assign(socket,
            selected_device: device,
            latest_telemetry: telemetry,
            live_reading:
              if(
                device.connectivity_status == :offline or
                  device.lamp_status in [:offline, :power_failure],
                do: nil,
                else: socket.assigns.live_reading
              )
          ),
        else: socket

    {:noreply, refresh(socket)}
  end

  def handle_info({:device_status_updated, device}, socket) do
    socket =
      if socket.assigns.selected_device && socket.assigns.selected_device.id == device.id,
        do: assign(socket, :selected_device, device),
        else: socket

    {:noreply, refresh(socket)}
  end

  def handle_info({:dashboard_summary_updated, summary}, socket),
    do: {:noreply, assign(socket, :summary, summary)}

  def handle_info({:live_sensor_reading, device_id, reading}, socket) do
    if socket.assigns.selected_device && socket.assigns.selected_device.id == device_id,
      do: {:noreply, assign(socket, :live_reading, reading)},
      else: {:noreply, socket}
  end

  def handle_info({:repair_dispatched, dispatch}, socket),
    do: {:noreply, assign(socket, :active_repair, dispatch)}

  def handle_info({:repair_status_updated, dispatch}, socket),
    do:
      {:noreply,
       socket |> assign(:active_repair, dispatch) |> push_event("repair_status_updated", dispatch)}

  def handle_info({:repair_completed, dispatch, _device}, socket),
    do:
      {:noreply,
       socket |> assign(:active_repair, nil) |> push_event("repair_completed", dispatch)}

  def handle_info({:repair_failed, dispatch}, socket),
    do:
      {:noreply,
       socket |> assign(:active_repair, nil) |> push_event("repair_completed", dispatch)}

  def handle_info({:technician_returning, route}, socket),
    do: {:noreply, push_event(socket, "technician_returning", route)}

  def handle_info({:technician_returned, route}, socket),
    do: {:noreply, push_event(socket, "technician_returned", route)}

  def scenarios, do: @scenarios

  def lamp_asset(device) do
    cond do
      device.security_status in [:suspected_vandalism, :critical] ->
        ~p"/images/lamps/vandalism.svg"

      device.lamp_status == :overheated ->
        ~p"/images/lamps/overheated.svg"

      device.lamp_status == :power_failure ->
        ~p"/images/lamps/power-failure.svg"

      device.connectivity_status == :offline ->
        ~p"/images/lamps/offline.svg"

      true ->
        ~p"/images/lamps/normal.svg"
    end
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  def status(assigns) do
    ~H"""
    <div class="rounded-xl bg-slate-50 p-3">
      <span class="block text-[9px] font-bold uppercase tracking-wider text-slate-500">{@label}</span><strong class="mt-1 block truncate text-xs uppercase text-slate-800">{@value}</strong>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :tone, :string, required: true

  defp public_stat(assigns) do
    ~H"""
    <div class="min-w-24 rounded-xl border border-slate-200 bg-white px-4 py-3">
      <span class="block text-[9px] font-bold uppercase tracking-wider text-slate-500">{@label}</span><strong class={[
        "mt-1 block text-xl",
        @tone == "emerald" && "text-emerald-700",
        @tone == "amber" && "text-amber-700"
      ]}>{@value}</strong>
    </div>
    """
  end

  defp refresh(socket) do
    devices = Devices.list_devices()
    public_devices = Enum.map(devices, &public_map_device/1)

    socket
    |> assign(:summary, Monitoring.summary(devices))
    |> assign(:map_devices, public_devices)
    |> push_event("devices_updated", %{devices: public_devices})
  end

  defp public_map_device(device) do
    device
    |> Monitoring.map_device()
    |> Map.take([
      :id,
      :device_code,
      :name,
      :latitude,
      :longitude,
      :status,
      :lamp_status,
      :connectivity_status
    ])
    |> Map.put(:address, "Jakarta public lighting zone")
  end
end
