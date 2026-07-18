defmodule SmartCityLampWeb.DeviceDetailLive do
  use SmartCityLampWeb, :live_view

  alias SmartCityLamp.Commands
  alias SmartCityLamp.Devices
  alias SmartCityLamp.Incidents
  alias SmartCityLamp.Monitoring
  alias SmartCityLamp.Repairs
  alias SmartCityLamp.Simulations.LiveSensorBroadcaster
  alias SmartCityLamp.Telemetry

  @chart_specs [
    {:voltage, "Voltage", "V", "#67e8f9"},
    {:current, "Current", "A", "#a78bfa"},
    {:led_temperature, "LED temperature", "°C", "#fb7185"},
    {:vibration, "Vibration", "g", "#fbbf24"},
    {:activity, "Activity count", "count", "#34d399"}
  ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    device = Devices.get_device!(id)

    if connected?(socket),
      do: Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, "device:#{device.id}")

    {:ok,
     socket
     |> assign(:page_title, device.name)
     |> assign(:live_reading, LiveSensorBroadcaster.latest(device.id))
     |> assign(:repair_dispatch, Repairs.get(device.id))
     |> assign(:repair_map_devices, [Monitoring.map_device(device)])
     |> assign(:command_form, command_form(device))
     |> assign(:selected_command, "SET_BRIGHTNESS")
     |> refresh(device)}
  end

  @impl true
  def handle_event("validate_command", %{"command" => params}, socket) do
    {:noreply,
     socket
     |> assign(:selected_command, params["command_type"])
     |> assign(:command_form, to_form(params, as: :command))}
  end

  def handle_event("issue_command", %{"command" => params}, socket) do
    attrs = %{
      "command_type" => params["command_type"],
      "payload" => %{"brightness_level" => params["brightness_level"]}
    }

    case Commands.issue(socket.assigns.device, attrs) do
      {:ok, command, device} ->
        {:noreply,
         socket
         |> assign(:command_form, command_form(device))
         |> refresh(device)
         |> put_flash(:info, "#{command.command_type} executed successfully")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Command rejected: #{inspect(reason)}")}
    end
  end

  def handle_event("maintenance", %{"mode" => mode}, socket) do
    command = if mode == "enter", do: "ENTER_MAINTENANCE", else: "EXIT_MAINTENANCE"

    case Commands.issue(socket.assigns.device, %{"command_type" => command}) do
      {:ok, _command, device} ->
        {:noreply, refresh(socket, device)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Maintenance command failed: #{inspect(reason)}")}
    end
  end

  def handle_event("recover_device", _params, socket) do
    case Repairs.dispatch(socket.assigns.device, socket.assigns.current_admin.email) do
      {:ok, dispatch} ->
        {:noreply,
         socket
         |> assign(:repair_dispatch, dispatch)
         |> put_flash(:info, "Technician dispatched. Recovery will begin after arrival.")}

      {:error, {:already_dispatched, dispatch}} ->
        {:noreply, assign(socket, :repair_dispatch, dispatch)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Technician dispatch failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:telemetry_received, _telemetry}, socket),
    do: {:noreply, refresh(socket, Devices.get_device!(socket.assigns.device.id))}

  def handle_info({:device_status_updated, device}, socket),
    do: {:noreply, refresh(socket, device)}

  def handle_info({:command_executed, _command, device}, socket),
    do: {:noreply, refresh(socket, device)}

  def handle_info(
        {:live_sensor_reading, device_id, reading},
        %{assigns: %{device: %{id: device_id}}} = socket
      ),
      do: {:noreply, assign(socket, :live_reading, reading)}

  def handle_info({:live_sensor_reading, _device_id, _reading}, socket),
    do: {:noreply, socket}

  def handle_info({:repair_dispatched, dispatch}, socket),
    do: {:noreply, assign(socket, :repair_dispatch, dispatch)}

  def handle_info({:repair_status_updated, dispatch}, socket),
    do:
      {:noreply,
       socket
       |> assign(:repair_dispatch, dispatch)
       |> push_event("repair_status_updated", dispatch)}

  def handle_info({:repair_completed, dispatch, device}, socket) do
    {:noreply,
     socket
     |> assign(:repair_dispatch, nil)
     |> refresh(device)
     |> push_event("repair_completed", dispatch)
     |> put_flash(:info, "Technician completed the repair. Device is online.")}
  end

  def handle_info({:repair_failed, dispatch}, socket),
    do:
      {:noreply,
       socket
       |> assign(:repair_dispatch, nil)
       |> put_flash(:error, "Repair failed: #{dispatch.reason}")}

  def handle_info({:technician_returning, route}, socket),
    do: {:noreply, push_event(socket, "technician_returning", route)}

  def handle_info({:technician_returned, route}, socket),
    do: {:noreply, push_event(socket, "technician_returned", route)}

  def chart_specs, do: @chart_specs

  attr :label, :string, required: true
  attr :unit, :string, required: true
  attr :color, :string, required: true
  attr :points, :string, required: true
  attr :latest, :any, required: true

  def telemetry_chart(assigns) do
    ~H"""
    <article class="rounded-xl border border-slate-200/70 bg-slate-50 p-4">
      <div class="flex items-end justify-between">
        <div>
          <h3 class="text-xs font-semibold text-slate-700">{@label}</h3><p class="mt-1 text-[10px] text-slate-600">
            Last 30 transmissions
          </p>
        </div><strong class="font-mono text-sm text-slate-900">{@latest}<small class="ml-1 text-[9px] text-slate-500">{@unit}</small></strong>
      </div>
      <svg
        viewBox="0 0 300 80"
        class="mt-3 h-20 w-full overflow-visible"
        role="img"
        aria-label={@label}
      >
        <line x1="0" y1="79" x2="300" y2="79" stroke="rgba(148,163,184,.12)" />
        <polyline
          points={@points}
          fill="none"
          stroke={@color}
          stroke-width="2.5"
          stroke-linecap="round"
          stroke-linejoin="round"
          vector-effect="non-scaling-stroke"
        />
      </svg>
    </article>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  def profile_item(assigns) do
    ~H"""
    <article class="flex items-start gap-3 rounded-xl border border-slate-200/70 bg-white p-4">
      <span class="grid size-8 shrink-0 place-items-center rounded-lg bg-teal-50 text-teal-700"><.icon
        name={@icon}
        class="size-4"
      /></span>
      <div class="min-w-0">
        <span class="block text-[9px] font-bold uppercase tracking-wider text-slate-600">{@label}</span><strong class="mt-1 block truncate text-xs text-slate-700">{@value}</strong>
      </div>
    </article>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  def status_item(assigns) do
    ~H"""
    <article class="rounded-xl bg-slate-50 p-3">
      <span class="block text-[9px] font-bold uppercase tracking-wider text-slate-600">{@label}</span><strong class="mt-1 block truncate text-xs uppercase text-slate-700">{@value}</strong>
    </article>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  def reading(assigns) do
    ~H"""
    <div class="rounded-lg bg-slate-50 p-3">
      <span class="block text-[9px] uppercase tracking-wider text-slate-600">{@label}</span><strong class="mt-1 block font-mono text-xs text-slate-900">{@value}</strong>
    </div>
    """
  end

  defp refresh(socket, device) do
    history = Telemetry.history_for_device(device.id)
    incidents = Incidents.list_for_device(device.id)
    commands = Commands.list_for_device(device.id)
    events = Devices.list_events(device.id)

    socket
    |> assign(:device, device)
    |> assign(:repair_map_devices, [Monitoring.map_device(device)])
    |> assign(:latest_telemetry, List.last(history))
    |> assign(:chart_data, chart_data(history))
    |> assign(:incidents_empty?, incidents == [])
    |> assign(:commands_empty?, commands == [])
    |> assign(:events_empty?, events == [])
    |> stream(:device_incidents, incidents, reset: true)
    |> stream(:device_commands, commands, reset: true)
    |> stream(:device_events, events, reset: true)
  end

  defp command_form(device) do
    to_form(
      %{"command_type" => "SET_BRIGHTNESS", "brightness_level" => device.brightness_level},
      as: :command
    )
  end

  defp chart_data([]) do
    Map.new(@chart_specs, fn {field, _label, _unit, _color} ->
      {field, %{points: "", latest: "—"}}
    end)
  end

  defp chart_data(history) do
    Map.new(@chart_specs, fn {field, _label, _unit, _color} ->
      values = Enum.map(history, &chart_value(&1, field))
      {field, %{points: points(values), latest: values |> List.last() |> format_value()}}
    end)
  end

  defp chart_value(record, :activity), do: record.pedestrian_count + record.vehicle_count
  defp chart_value(record, field), do: Map.fetch!(record, field)

  defp points(values) do
    minimum = Enum.min(values)
    maximum = Enum.max(values)
    range = max(maximum - minimum, 0.0001)
    denominator = max(length(values) - 1, 1)

    values
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {value, index} ->
      x = index / denominator * 300
      y = 72 - (value - minimum) / range * 64
      "#{Float.round(x, 2)},#{Float.round(y, 2)}"
    end)
  end

  defp format_value(value) when is_float(value), do: Float.round(value, 2)
  defp format_value(value), do: value
end
