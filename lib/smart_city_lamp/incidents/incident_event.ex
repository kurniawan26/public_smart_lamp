defmodule SmartCityLamp.Incidents.IncidentEvent do
  use Ecto.Schema
  import Ecto.Changeset

  alias SmartCityLamp.Incidents.Incident

  schema "incident_events" do
    field :event_type, :string
    field :actor, :string
    field :notes, :string
    field :metadata, :map, default: %{}

    belongs_to :incident, Incident
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :actor, :notes, :metadata])
    |> validate_required([:incident_id, :event_type, :actor])
    |> foreign_key_constraint(:incident_id)
  end
end
