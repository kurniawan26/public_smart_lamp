defmodule SmartCityLampWeb.TelemetryController do
  use SmartCityLampWeb, :controller

  alias SmartCityLamp.Telemetry

  def create(conn, params) do
    case Telemetry.ingest(params) do
      {:ok, telemetry, device} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: telemetry_json(telemetry, device.device_code),
          meta: %{received_at: DateTime.utc_now()},
          errors: []
        })

      {:error, :unknown_device} ->
        error(conn, :not_found, "UNKNOWN_DEVICE", "Device is not registered")

      {:error, :device_code_required} ->
        validation_error(conn, %{"device_code" => ["is required"]})

      {:error, %Ecto.Changeset{} = changeset} ->
        validation_error(conn, errors_on(changeset))
    end
  end

  defp telemetry_json(telemetry, device_code) do
    %{
      id: telemetry.id,
      device_code: device_code,
      recorded_at: telemetry.recorded_at,
      voltage: telemetry.voltage,
      current: telemetry.current,
      power_watt: telemetry.power_watt,
      brightness_level: telemetry.brightness_level,
      latitude: telemetry.latitude,
      longitude: telemetry.longitude
    }
  end

  defp validation_error(conn, fields) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      data: nil,
      meta: %{},
      errors: [
        %{code: "VALIDATION_ERROR", message: "Invalid telemetry payload", fields: fields}
      ]
    })
  end

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{data: nil, meta: %{}, errors: [%{code: code, message: message, fields: %{}}]})
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, options} ->
      Enum.reduce(options, message, fn {key, value}, result ->
        String.replace(result, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
