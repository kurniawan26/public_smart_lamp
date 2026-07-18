defmodule SmartCityLampWeb.Api.SimulatorEventController do
  use SmartCityLampWeb, :controller

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Simulations

  def create(conn, %{"device_code" => device_code, "event" => event}) do
    with device when not is_nil(device) <- Devices.get_device_by_code(device_code),
         {:ok, result} <- Simulations.run_scenario(device, event, rate_key: rate_key(conn)) do
      conn
      |> put_status(:created)
      |> json(%{
        data: %{
          device_code: result.device.device_code,
          event: event,
          telemetry_id: result.telemetry.id,
          device_status: result.device.security_status |> to_string() |> String.upcase(),
          incident_created: result.incident_created
        },
        meta: %{},
        errors: []
      })
    else
      nil ->
        error(conn, :not_found, "UNKNOWN_DEVICE", "Device is not registered")

      {:error, :invalid_simulation_event} ->
        error(
          conn,
          :unprocessable_entity,
          "INVALID_SIMULATION_EVENT",
          "Unsupported simulation event"
        )

      {:error, :device_cooldown} ->
        error(
          conn,
          :too_many_requests,
          "SIMULATION_COOLDOWN",
          "Wait before sending another event to this device"
        )

      {:error, :rate_limit_exceeded} ->
        error(conn, :too_many_requests, "RATE_LIMIT_EXCEEDED", "Too many simulation events")

      {:error, _reason} ->
        error(
          conn,
          :unprocessable_entity,
          "SIMULATION_FAILED",
          "Simulation could not be processed"
        )
    end
  end

  def create(conn, _params),
    do:
      error(conn, :unprocessable_entity, "VALIDATION_ERROR", "device_code and event are required")

  defp rate_key(conn), do: "ip:" <> (conn.remote_ip |> :inet.ntoa() |> to_string())

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{data: nil, meta: %{}, errors: [%{code: code, message: message}]})
  end
end
