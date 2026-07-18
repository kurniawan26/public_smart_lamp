defmodule SmartCityLamp.Repairs do
  import Ecto.Query

  alias SmartCityLamp.Devices.Device
  alias SmartCityLamp.Repairs.RepairDispatch
  alias SmartCityLamp.Repo
  alias SmartCityLamp.Workers.RepairWorker

  @office %{latitude: -6.1805, longitude: 106.8284, name: "Jakarta Technician Office"}
  @topic "repairs"
  @active_statuses [:queued, :en_route, :repairing]
  @visible_statuses [:queued, :en_route, :repairing, :returning]

  def subscribe, do: Phoenix.PubSub.subscribe(SmartCityLamp.PubSub, @topic)
  def office, do: @office

  def dispatch(%Device{} = device, actor) do
    Repo.transaction(fn ->
      # One lock serializes origin calculation and queue insertion for the single MVP technician.
      Repo.query!("SELECT pg_advisory_xact_lock($1)", [71_403])

      case active_for_device(device.id) do
        %RepairDispatch{} = dispatch ->
          Repo.rollback({:already_dispatched, to_map(dispatch)})

        nil ->
          origin = next_origin()

          dispatch =
            %RepairDispatch{device_id: device.id}
            |> RepairDispatch.create_changeset(%{
              actor: actor,
              origin_latitude: origin.latitude,
              origin_longitude: origin.longitude,
              origin_name: origin.name,
              destination_latitude: device.latitude,
              destination_longitude: device.longitude,
              destination_name: device.name,
              travel_ms: Application.get_env(:smart_city_lamp, :technician_travel_ms, 15_000),
              repair_ms: Application.get_env(:smart_city_lamp, :technician_repair_ms, 8_000)
            })
            |> Repo.insert!()

          job = %{dispatch_id: dispatch.id} |> RepairWorker.new() |> Oban.insert!()

          dispatch =
            dispatch
            |> RepairDispatch.state_changeset(%{oban_job_id: job.id})
            |> Repo.update!()

          broadcast(dispatch.device_id, {:repair_dispatched, to_map(dispatch)})
          to_map(dispatch)
      end
    end)
    |> case do
      {:ok, dispatch} -> {:ok, dispatch}
      {:error, {:already_dispatched, dispatch}} -> {:error, {:already_dispatched, dispatch}}
      {:error, reason} -> {:error, reason}
    end
  end

  def get(device_id) do
    device_id
    |> active_for_device()
    |> case do
      nil -> nil
      dispatch -> to_map(dispatch)
    end
  end

  defp active_for_device(device_id) do
    RepairDispatch
    |> where([d], d.device_id == ^device_id and d.status in ^@active_statuses)
    |> order_by([d], desc: d.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def list_active do
    RepairDispatch
    |> where([d], d.status in ^@visible_statuses)
    |> order_by([d], asc: d.inserted_at)
    |> Repo.all()
    |> Enum.map(&to_map/1)
  end

  def queued_after?(dispatch_id) do
    Repo.exists?(from d in RepairDispatch, where: d.status == :queued and d.id != ^dispatch_id)
  end

  def fetch!(id), do: Repo.get!(RepairDispatch, id)

  def update!(%RepairDispatch{} = dispatch, attrs) do
    dispatch
    |> RepairDispatch.state_changeset(attrs)
    |> Repo.update!()
  end

  def broadcast(device_id, message) do
    Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, @topic, message)
    Phoenix.PubSub.broadcast(SmartCityLamp.PubSub, "device:#{device_id}", message)
  end

  def to_map(%RepairDispatch{} = dispatch) do
    %{
      id: dispatch.id,
      device_id: dispatch.device_id,
      device_code: device_code(dispatch),
      actor: dispatch.actor,
      status: dispatch.status,
      office: @office,
      origin: %{
        latitude: dispatch.origin_latitude,
        longitude: dispatch.origin_longitude,
        name: dispatch.origin_name
      },
      destination: %{
        latitude: dispatch.destination_latitude,
        longitude: dispatch.destination_longitude,
        name: dispatch.destination_name
      },
      travel_ms: dispatch.travel_ms,
      repair_ms: dispatch.repair_ms,
      dispatched_at: dispatch.inserted_at,
      en_route_at: dispatch.en_route_at,
      arrived_at: dispatch.arrived_at,
      completed_at: dispatch.completed_at,
      return_started_at: dispatch.return_started_at,
      returned_at: dispatch.returned_at
    }
  end

  defp next_origin do
    RepairDispatch
    |> where([d], d.status in ^@active_statuses)
    |> order_by([d], desc: d.inserted_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil ->
        @office

      dispatch ->
        %{
          latitude: dispatch.destination_latitude,
          longitude: dispatch.destination_longitude,
          name: dispatch.destination_name
        }
    end
  end

  defp device_code(%RepairDispatch{device: %Device{} = device}), do: device.device_code

  defp device_code(%RepairDispatch{} = dispatch) do
    Repo.get!(Device, dispatch.device_id).device_code
  end
end
