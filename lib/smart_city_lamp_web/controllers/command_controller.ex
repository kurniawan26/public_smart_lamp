defmodule SmartCityLampWeb.CommandController do
  use SmartCityLampWeb, :controller

  alias SmartCityLamp.Commands
  alias SmartCityLamp.Devices

  def create(conn, %{"id" => id} = params) do
    device = Devices.get_device!(id)

    attrs = %{
      "command_type" => params["command_type"],
      "payload" => Map.get(params, "payload", %{})
    }

    case Commands.issue(device, attrs, "api_operator") do
      {:ok, command, updated_device} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            id: command.id,
            device_code: updated_device.device_code,
            command_type: command.command_type,
            payload: command.payload,
            status: command.status,
            requested_at: command.requested_at,
            executed_at: command.executed_at,
            response_message: command.response_message
          },
          meta: %{},
          errors: []
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          data: nil,
          meta: %{},
          errors: [
            %{
              code: "COMMAND_REJECTED",
              message: "Remote command was rejected",
              fields: %{command: inspect(reason)}
            }
          ]
        })
    end
  end
end
