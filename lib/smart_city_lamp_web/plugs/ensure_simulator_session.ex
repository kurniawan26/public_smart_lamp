defmodule SmartCityLampWeb.Plugs.EnsureSimulatorSession do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :simulator_session_id) do
      conn
    else
      put_session(
        conn,
        :simulator_session_id,
        Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
      )
    end
  end
end
