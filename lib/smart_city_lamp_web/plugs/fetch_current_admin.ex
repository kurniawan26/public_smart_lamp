defmodule SmartCityLampWeb.Plugs.FetchCurrentAdmin do
  import Plug.Conn

  alias SmartCityLamp.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    assign(conn, :current_admin, Accounts.get_admin(get_session(conn, :admin_id)))
  end
end
