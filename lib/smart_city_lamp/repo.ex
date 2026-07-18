defmodule SmartCityLamp.Repo do
  use Ecto.Repo,
    otp_app: :smart_city_lamp,
    adapter: Ecto.Adapters.Postgres
end
