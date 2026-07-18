defmodule SmartCityLampWeb.Plugs.RequirePublicEmulator do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if Application.get_env(:smart_city_lamp, :enable_public_emulator, false) do
      conn
    else
      conn |> send_resp(:not_found, "Not found") |> halt()
    end
  end
end
