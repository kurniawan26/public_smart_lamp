defmodule SmartCityLampWeb.AdminAuth do
  import Phoenix.Component
  import Phoenix.LiveView

  alias SmartCityLamp.Accounts

  use SmartCityLampWeb, :verified_routes

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case Accounts.get_admin(session["admin_id"]) do
      nil ->
        {:halt,
         socket
         |> put_flash(:error, "Please sign in to access the admin area.")
         |> redirect(to: ~p"/admin/login")}

      admin ->
        {:cont, assign(socket, :current_admin, admin)}
    end
  end
end
