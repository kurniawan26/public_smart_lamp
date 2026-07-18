defmodule SmartCityLampWeb.Admin.SectionLive do
  use SmartCityLampWeb, :live_view

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Incidents

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: title(socket.assigns.live_action),
       devices: Devices.list_devices(),
       incidents: Incidents.list_incidents()
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_admin={@current_admin}>
      <div class="mx-auto max-w-[1400px] px-5 py-10 sm:px-8">
        <p class="text-xs font-bold uppercase tracking-[0.22em] text-teal-700">Admin operations</p><h1 class="mt-3 text-4xl font-semibold tracking-tight text-slate-900">
          {@page_title}
        </h1>
        <section
          id={"admin-section-#{@live_action}"}
          class="mt-8 rounded-[2rem] border border-slate-200 bg-white p-6 shadow-[0_24px_60px_-42px_rgba(51,65,85,.45)]"
        >
          <%= case @live_action do %>
            <% :devices -> %>
              <div class="space-y-2">
                <.link
                  :for={device <- @devices}
                  navigate={~p"/admin/devices/#{device.id}"}
                  class="flex items-center justify-between rounded-xl border border-slate-200 px-4 py-3 hover:border-teal-300 hover:bg-teal-50"
                ><span><strong class="block text-sm text-slate-900">{device.name}</strong><small class="text-slate-500">{device.device_code}</small></span><span class="text-xs font-semibold uppercase text-slate-600">{device.connectivity_status}</span></.link>
              </div>
            <% :incidents -> %>
              <div class="space-y-2">
                <article :for={incident <- @incidents} class="rounded-xl border border-slate-200 p-4">
                  <div class="flex justify-between gap-4">
                    <strong class="text-sm text-slate-900">{incident.title}</strong><span class="text-xs font-bold uppercase text-rose-700">{incident.status}</span>
                  </div><p class="mt-1 text-xs text-slate-500">
                    {incident.incident_type} · score {incident.confidence_score}
                  </p>
                </article>
              </div>
            <% _ -> %>
              <div class="py-16 text-center">
                <.icon name="hero-wrench-screwdriver" class="mx-auto size-8 text-teal-700" /><p class="mt-4 text-sm text-slate-600">
                  This protected operational workspace is ready for the next MVP iteration.
                </p>
              </div>
          <% end %>
        </section>
      </div>
    </Layouts.admin>
    """
  end

  defp title(:devices), do: "Device registry"
  defp title(:incidents), do: "Incident management"
  defp title(:incident), do: "Incident detail"
  defp title(:commands), do: "Remote commands"
  defp title(:settings), do: "Detection settings"
  defp title(:simulator_controls), do: "Simulator controls"
end
