defmodule SmartCityLampWeb.Plugs.RedirectIfAdminAuthenticated do
  import Phoenix.Controller
  import Plug.Conn

  use SmartCityLampWeb, :verified_routes

  def init(opts), do: opts

  def call(%{assigns: %{current_admin: admin}} = conn, _opts) when not is_nil(admin) do
    conn |> redirect(to: ~p"/admin/dashboard") |> halt()
  end

  def call(conn, _opts), do: conn
end
