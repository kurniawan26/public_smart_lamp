defmodule SmartCityLampWeb.Plugs.RequireAuthenticatedAdmin do
  import Phoenix.Controller
  import Plug.Conn

  use SmartCityLampWeb, :verified_routes

  def init(opts), do: opts

  def call(%{assigns: %{current_admin: admin}} = conn, _opts) when not is_nil(admin), do: conn

  def call(conn, _opts) do
    conn
    |> put_flash(:error, "Please sign in to access the admin area.")
    |> redirect(to: ~p"/admin/login")
    |> halt()
  end
end
