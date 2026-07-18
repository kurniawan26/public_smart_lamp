defmodule SmartCityLampWeb.IncidentController do
  use SmartCityLampWeb, :controller

  alias SmartCityLamp.Incidents

  def index(conn, _params) do
    json(conn, %{
      data: Enum.map(Incidents.list_incidents(), &incident_json/1),
      meta: %{},
      errors: []
    })
  end

  def acknowledge(conn, %{"id" => id}) do
    case Incidents.acknowledge(id, "api_operator") do
      {:ok, incident} -> json(conn, %{data: incident_json(incident), meta: %{}, errors: []})
      {:error, reason} -> lifecycle_error(conn, reason)
    end
  end

  def resolve(conn, %{"id" => id} = params) do
    notes = Map.get(params, "resolution_notes", "Resolved through incident API")

    case Incidents.resolve(id, "api_operator", notes) do
      {:ok, incident} -> json(conn, %{data: incident_json(incident), meta: %{}, errors: []})
      {:error, reason} -> lifecycle_error(conn, reason)
    end
  end

  defp incident_json(incident) do
    %{
      id: incident.id,
      device_code: incident.device.device_code,
      incident_type: incident.incident_type,
      severity: incident.severity,
      status: incident.status,
      confidence_score: incident.confidence_score,
      title: incident.title,
      description: incident.description,
      detected_signals: incident.detected_signals,
      detected_at: incident.detected_at,
      acknowledged_at: incident.acknowledged_at,
      resolved_at: incident.resolved_at,
      resolution_notes: incident.resolution_notes
    }
  end

  defp lifecycle_error(conn, :invalid_transition) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      data: nil,
      meta: %{},
      errors: [
        %{
          code: "INVALID_TRANSITION",
          message: "Incident status transition is not allowed",
          fields: %{}
        }
      ]
    })
  end

  defp lifecycle_error(conn, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      data: nil,
      meta: %{},
      errors: [
        %{
          code: "VALIDATION_ERROR",
          message: "Incident update failed",
          fields: inspect(changeset.errors)
        }
      ]
    })
  end
end
