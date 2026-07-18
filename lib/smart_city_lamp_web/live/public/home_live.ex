defmodule SmartCityLampWeb.Public.HomeLive do
  use SmartCityLampWeb, :live_view

  def mount(_params, _session, socket), do: {:ok, assign(socket, :page_title, "Smart City Lamp")}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto grid min-h-[calc(100vh-4rem)] max-w-[1400px] items-center gap-12 px-5 py-14 sm:px-8 lg:grid-cols-[1.05fr_.95fr] lg:py-24">
        <section>
          <p class="text-xs font-bold uppercase tracking-[0.24em] text-teal-700">
            Jakarta smart infrastructure MVP
          </p>
          <h1 class="mt-5 max-w-4xl text-5xl font-semibold tracking-[-0.045em] text-slate-900 sm:text-6xl lg:text-7xl">
            See how a city responds when every lamp can speak.
          </h1>
          <p class="mt-6 max-w-2xl text-base leading-8 text-slate-600">
            Select a lamp on the public map, trigger a safe scenario from its detail drawer, and watch the network respond through realtime telemetry and detection.
          </p>
          <div class="mt-9 flex flex-wrap gap-3">
            <.link
              navigate={~p"/public-map"}
              id="open-interactive-map"
              class="rounded-xl bg-teal-700 px-5 py-3 text-sm font-bold text-white hover:bg-teal-800"
            >Open interactive map</.link>
            <.link
              navigate={~p"/about"}
              id="open-about"
              class="rounded-xl border border-slate-200 bg-white px-5 py-3 text-sm font-bold text-slate-700 hover:border-teal-300 hover:bg-teal-50"
            >How it works</.link>
          </div>
        </section>
        <section class="relative min-h-[430px] overflow-hidden rounded-[2.5rem] border border-slate-200 bg-[#e7efeb] p-8 shadow-[0_32px_80px_-48px_rgba(51,65,85,.55)]">
          <div class="absolute inset-x-8 top-8 flex items-center justify-between text-xs font-semibold text-slate-600">
            <span>LIVE NETWORK</span><span class="rounded-full bg-white/80 px-3 py-1.5 text-emerald-700">20 lamps online</span>
          </div>
          <div class="absolute bottom-0 left-1/2 h-[340px] w-3 -translate-x-1/2 rounded-t-full bg-slate-700">
          </div>
          <div class="absolute bottom-[320px] left-1/2 h-20 w-44 -translate-x-1/2 rounded-[50%] bg-amber-100 ring-1 ring-amber-200">
          </div>
          <div class="absolute bottom-10 left-10 rounded-2xl border border-white/80 bg-white/90 p-4 shadow-sm">
            <p class="text-[10px] uppercase tracking-wider text-slate-500">Network health</p><strong class="mt-1 block text-2xl text-slate-900">98.4%</strong>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
