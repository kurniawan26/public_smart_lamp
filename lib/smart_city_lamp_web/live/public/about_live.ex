defmodule SmartCityLampWeb.Public.AboutLive do
  use SmartCityLampWeb, :live_view

  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "About the MVP")}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl px-5 py-16 sm:px-8">
        <p class="text-xs font-bold uppercase tracking-[0.24em] text-teal-700">About the project</p>
        <h1 class="mt-4 text-4xl font-semibold tracking-tight text-slate-900 sm:text-5xl">
          A safe digital twin for smarter street lighting.
        </h1>
        <p class="mt-6 max-w-3xl text-base leading-8 text-slate-600">
          This MVP models telemetry, environmental conditions, vandalism signals, traffic, and crowd activity for twenty simulated lamps around Jakarta. Public visitors can only trigger curated scenarios; operational actions remain protected inside the admin console.
        </p>
        <div class="mt-12 grid gap-5 md:grid-cols-2">
          <article class="rounded-[2rem] border border-slate-200 bg-white p-7">
            <.icon name="hero-globe-asia-australia" class="size-7 text-teal-700" /><h2 class="mt-5 text-xl font-semibold text-slate-900">
              Public simulation
            </h2><p class="mt-2 text-sm leading-6 text-slate-600">
              Scenario-only events demonstrate how a real IoT device could affect the network without exposing raw telemetry controls.
            </p>
          </article>
          <article class="rounded-[2rem] border border-slate-200 bg-white p-7">
            <.icon name="hero-shield-check" class="size-7 text-teal-700" /><h2 class="mt-5 text-xl font-semibold text-slate-900">
              Protected operations
            </h2><p class="mt-2 text-sm leading-6 text-slate-600">
              Authentication separates public education from incident acknowledgement, resolution, commands, and infrastructure details.
            </p>
          </article>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
