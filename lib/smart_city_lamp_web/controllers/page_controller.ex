defmodule SmartCityLampWeb.PageController do
  use SmartCityLampWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
