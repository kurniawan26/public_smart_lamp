defmodule SmartCityLampWeb.MonitoringLive do
  use SmartCityLampWeb, :live_view

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Monitoring
  alias SmartCityLamp.Repairs
  alias SmartCityLamp.Simulations.LiveSensorBroadcaster
  alias SmartCityLamp.Telemetry

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Telemetry.subscribe_dashboard()
      Incidents.subscribe()
      LiveSensorBroadcaster.subscribe()
      Repairs.subscribe()
    end

    devices = Devices.list_devices()
    incidents = Incidents.list_active_incidents()

    {:ok,
     socket
     |> assign(:page_title, "City Lamp Monitoring")
     |> assign(:resolving_incident_id, nil)
     |> assign(:selected_device, nil)
     |> assign(:selected_live_reading, nil)
     |> assign(:selected_repair, nil)
     |> assign(:active_repair, List.first(Repairs.list_active()))
     |> assign(:resolution_form, to_form(%{"resolution_notes" => ""}, as: :resolution))
     |> assign_dashboard(devices)
     |> assign(:incident_summary, Incidents.summary())
     |> assign(:incidents_empty?, incidents == [])
     |> stream(:recent_telemetry, Telemetry.list_recent(6))
     |> stream(:live_sensors, [])
     |> stream(:active_incidents, incidents)}
  end

  @impl true
  def handle_info({:dashboard_updated, _device, telemetry}, socket) do
    {:noreply,
     socket
     |> assign_dashboard(Devices.list_devices())
     |> stream_insert(:recent_telemetry, telemetry, at: 0, limit: 6)
     |> put_flash(:info, "New telemetry received from #{telemetry.device.device_code}")}
  end

  def handle_info({:device_status_updated, _device}, socket) do
    {:noreply, assign_dashboard(socket, Devices.list_devices())}
  end

  def handle_info({:dashboard_summary_updated, summary}, socket) do
    {:noreply, assign(socket, :summary, summary)}
  end

  def handle_info({:live_sensor_reading, device_id, reading}, socket) do
    socket =
      if socket.assigns.selected_device && socket.assigns.selected_device.id == device_id,
        do: assign(socket, :selected_live_reading, reading),
        else: socket

    {:noreply, stream_insert(socket, :live_sensors, reading, at: 0, limit: 6)}
  end

  def handle_info({:repair_dispatched, dispatch}, socket) do
    socket = socket |> assign(:active_repair, dispatch) |> maybe_assign_repair(dispatch)
    {:noreply, socket}
  end

  def handle_info({:repair_status_updated, dispatch}, socket) do
    socket = socket |> assign(:active_repair, dispatch) |> maybe_assign_repair(dispatch)
    {:noreply, push_event(socket, "repair_status_updated", dispatch)}
  end

  def handle_info({:repair_completed, dispatch, device}, socket) do
    socket =
      if socket.assigns.selected_device && socket.assigns.selected_device.id == device.id,
        do: assign(socket, selected_device: device, selected_repair: nil, active_repair: nil),
        else: assign(socket, :active_repair, nil)

    {:noreply, push_event(socket, "repair_completed", dispatch)}
  end

  def handle_info({:repair_failed, _dispatch}, socket), do: {:noreply, socket}

  def handle_info({:technician_returning, route}, socket),
    do: {:noreply, push_event(socket, "technician_returning", route)}

  def handle_info({:technician_returned, route}, socket),
    do: {:noreply, push_event(socket, "technician_returned", route)}

  def handle_info({event, incident}, socket)
      when event in [:incident_created, :incident_updated] do
    message =
      if event == :incident_created,
        do: "New #{incident.severity} incident detected",
        else: "Incident updated"

    {:noreply, socket |> refresh_incidents() |> put_flash(:info, message)}
  end

  @impl true
  def handle_event("select_device", %{"id" => id}, socket) do
    device = Devices.get_device!(id)

    {:noreply,
     assign(socket,
       selected_device: device,
       selected_repair: Repairs.get(device.id),
       selected_live_reading: LiveSensorBroadcaster.latest(device.id)
     )}
  rescue
    Ecto.NoResultsError -> {:noreply, put_flash(socket, :error, "Unknown device")}
  end

  def handle_event("close_device_dispatch", _params, socket),
    do: {:noreply, assign(socket, :selected_device, nil)}

  def handle_event(
        "dispatch_technician",
        _params,
        %{assigns: %{selected_device: device}} = socket
      )
      when not is_nil(device) do
    if repairable?(device) do
      dispatch_technician(socket, device)
    else
      {:noreply,
       put_flash(socket, :info, "#{device.device_code} is online and does not need repair")}
    end
  end

  def handle_event("acknowledge_incident", %{"id" => id}, socket) do
    case Incidents.acknowledge(id, socket.assigns.current_admin.email) do
      {:ok, _incident} ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not acknowledge: #{inspect(reason)}")}
    end
  end

  def handle_event("prepare_resolution", %{"id" => id}, socket) do
    {:noreply, assign(socket, :resolving_incident_id, id)}
  end

  def handle_event("cancel_resolution", _params, socket) do
    {:noreply, assign(socket, :resolving_incident_id, nil)}
  end

  def handle_event(
        "resolve_incident",
        %{"resolution" => %{"resolution_notes" => notes}},
        socket
      ) do
    case Incidents.resolve(
           socket.assigns.resolving_incident_id,
           socket.assigns.current_admin.email,
           notes
         ) do
      {:ok, _incident} ->
        {:noreply, assign(socket, :resolving_incident_id, nil)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not resolve: #{inspect(reason)}")}
    end
  end

  def marker_status(device), do: Monitoring.marker_status(device)

  def repairable?(device), do: device.connectivity_status != :online

  defp dispatch_technician(socket, device) do
    case Repairs.dispatch(device, socket.assigns.current_admin.email) do
      {:ok, dispatch} ->
        {:noreply,
         socket
         |> assign(:selected_repair, dispatch)
         |> put_flash(:info, "Technician dispatched to #{device.device_code}")}

      {:error, {:already_dispatched, dispatch}} ->
        {:noreply, assign(socket, :selected_repair, dispatch)}
    end
  end

  defp assign_dashboard(socket, devices) do
    map_devices = Enum.map(devices, &Monitoring.map_device/1)

    socket
    |> assign(:devices, devices)
    |> assign(:summary, Monitoring.summary(devices))
    |> assign(:map_devices, map_devices)
    |> push_event("devices_updated", %{devices: map_devices})
  end

  defp maybe_assign_repair(socket, dispatch) do
    if socket.assigns.selected_device && socket.assigns.selected_device.id == dispatch.device_id,
      do: assign(socket, :selected_repair, dispatch),
      else: socket
  end

  defp refresh_incidents(socket) do
    incidents = Incidents.list_active_incidents()

    socket
    |> assign(:incident_summary, Incidents.summary())
    |> assign(:incidents_empty?, incidents == [])
    |> stream(:active_incidents, incidents, reset: true)
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :tone, :string, required: true

  def stat(assigns) do
    ~H"""
    <article class="rounded-2xl border border-slate-200/80 bg-white p-4 shadow-[0_18px_45px_-30px_rgba(51,65,85,.4)]">
      <div class="flex items-center justify-between gap-3">
        <span class="text-[10px] font-bold uppercase tracking-wider text-slate-500">{@label}</span>
        <span class={[
          "grid size-8 shrink-0 place-items-center rounded-lg",
          @tone == "teal" && "bg-teal-50 text-teal-700",
          @tone == "emerald" && "bg-emerald-400/10 text-emerald-700",
          @tone == "slate" && "bg-slate-400/10 text-slate-700",
          @tone == "amber" && "bg-amber-400/10 text-amber-700",
          @tone == "rose" && "bg-rose-400/10 text-rose-700",
          @tone == "blue" && "bg-blue-400/10 text-blue-700"
        ]}><.icon name={@icon} class="size-4" /></span>
      </div>
      <p class="mt-4 text-3xl font-semibold tracking-tight text-slate-900">{@value}</p>
    </article>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true

  def condition(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-100 bg-slate-50 p-3">
      <div class="flex items-center gap-2 text-slate-500">
        <.icon name={@icon} class="size-3.5" />
        <span class="text-[9px] font-bold uppercase tracking-wide">{@label}</span>
      </div>
      <strong class="mt-2 block truncate text-xs capitalize text-slate-800">{@value}</strong>
    </div>
    """
  end
end
