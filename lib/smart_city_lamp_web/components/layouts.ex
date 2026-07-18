defmodule SmartCityLampWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SmartCityLampWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="sticky top-0 z-[1000] border-b border-slate-200/70 bg-[#f6f7f2]/90 px-5 backdrop-blur-xl sm:px-8">
      <div class="mx-auto flex h-16 max-w-[1500px] items-center justify-between">
        <.link navigate={~p"/"} class="group flex items-center gap-3 active:scale-[0.98]">
          <span class="grid size-9 place-items-center rounded-xl bg-teal-700 text-white shadow-[0_8px_20px_-12px_rgba(15,118,110,.8)] transition-transform group-hover:-rotate-3">
            <.icon name="hero-light-bulb" class="size-5" />
          </span>
          <span>
            <strong class="block text-sm tracking-wide text-slate-900">LUMEN GRID</strong>
            <small class="block text-[9px] uppercase tracking-[0.25em] text-slate-500">Smart infrastructure</small>
          </span>
        </.link>
        <nav class="flex items-center gap-1 rounded-xl border border-slate-200/80 bg-white/80 p-1 text-xs font-semibold text-slate-600 shadow-[0_12px_30px_-24px_rgba(51,65,85,.5)]">
          <.link
            navigate={~p"/public-map"}
            class="rounded-lg px-3 py-2 transition hover:bg-teal-50 hover:text-teal-800 active:scale-[0.98]"
          >Public map</.link>
          <.link
            navigate={~p"/about"}
            class="hidden rounded-lg px-3 py-2 transition hover:bg-teal-50 hover:text-teal-800 active:scale-[0.98] sm:block"
          >About</.link>
          <.link
            navigate={~p"/admin/login"}
            class="rounded-lg bg-teal-700 px-3 py-2 text-white hover:bg-teal-800"
          >Admin</.link>
        </nav>
      </div>
    </header>

    <main class="min-h-[calc(100vh-4rem)] bg-[#f6f7f2]">
      {render_slot(@inner_block)}
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :current_admin, :map, required: true
  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#f6f7f2] lg:grid lg:grid-cols-[240px_minmax(0,1fr)]">
      <aside class="border-b border-slate-200/80 bg-white px-5 py-4 lg:sticky lg:top-0 lg:h-screen lg:border-b-0 lg:border-r lg:px-4 lg:py-6">
        <div class="flex items-center justify-between lg:block">
          <.link navigate={~p"/admin/dashboard"} class="flex items-center gap-3 px-2">
            <span class="grid size-9 place-items-center rounded-xl bg-teal-700 text-white"><.icon
              name="hero-light-bulb"
              class="size-5"
            /></span>
            <span><strong class="block text-sm tracking-wide text-slate-900">LUMEN GRID</strong><small class="text-[9px] uppercase tracking-[0.2em] text-slate-500">Admin console</small></span>
          </.link>
          <nav class="mt-0 flex gap-1 overflow-x-auto text-xs font-semibold text-slate-600 lg:mt-9 lg:block lg:space-y-1">
            <.admin_link href={~p"/admin/dashboard"} icon="hero-squares-2x2">Dashboard</.admin_link>
            <.admin_link href={~p"/admin/devices"} icon="hero-light-bulb">Devices</.admin_link>
            <.admin_link href={~p"/admin/incidents"} icon="hero-shield-exclamation">Incidents</.admin_link>
            <.admin_link href={~p"/admin/commands"} icon="hero-command-line">Commands</.admin_link>
            <.admin_link href={~p"/admin/settings"} icon="hero-adjustments-horizontal">Settings</.admin_link>
          </nav>
        </div>
        <div class="mt-8 hidden border-t border-slate-200 pt-5 lg:block">
          <p class="px-2 text-xs font-semibold text-slate-800">{@current_admin.name}</p>
          <p class="mt-1 truncate px-2 text-[10px] text-slate-500">{@current_admin.email}</p>
          <.link
            href={~p"/admin/logout"}
            method="delete"
            class="mt-4 flex items-center gap-2 rounded-xl px-3 py-2 text-xs font-semibold text-rose-700 hover:bg-rose-50"
          ><.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Logout</.link>
        </div>
      </aside>
      <main class="min-w-0">{render_slot(@inner_block)}</main>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp admin_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="flex shrink-0 items-center gap-2.5 rounded-xl px-3 py-2.5 hover:bg-teal-50 hover:text-teal-800"
    ><.icon name={@icon} class="size-4" />{render_slot(@inner_block)}</.link>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
