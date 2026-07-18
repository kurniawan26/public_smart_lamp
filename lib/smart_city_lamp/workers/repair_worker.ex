defmodule SmartCityLamp.Workers.RepairWorker do
  use Oban.Worker, queue: :repairs, max_attempts: 3

  alias SmartCityLamp.Devices
  alias SmartCityLamp.Repairs
  alias SmartCityLamp.Simulations

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"dispatch_id" => dispatch_id}}) do
    dispatch = Repairs.fetch!(dispatch_id)

    case dispatch.status do
      :queued -> run_repair(dispatch)
      :en_route -> run_repair(dispatch)
      :repairing -> finish_repair(dispatch)
      :completed -> maybe_return_to_office(dispatch)
      :returning -> return_to_office(dispatch)
      :returned -> :ok
      :failed -> {:discard, dispatch.failure_reason || "repair already failed"}
    end
  rescue
    error ->
      mark_failed(dispatch_id, error)
      reraise error, __STACKTRACE__
  end

  defp run_repair(dispatch) do
    with {:ok, dispatch} <- travel(dispatch), do: finish_repair(dispatch)
  end

  defp finish_repair(dispatch) do
    with {:ok, dispatch} <- repair(dispatch),
         {:ok, result} <-
           Simulations.recover_device(
             Devices.get_device!(dispatch.device_id),
             dispatch.actor
           ) do
      completed =
        Repairs.update!(dispatch, %{status: :completed, completed_at: DateTime.utc_now()})

      Repairs.broadcast(
        dispatch.device_id,
        {:repair_completed, Repairs.to_map(completed), result.device}
      )

      maybe_return_to_office(completed)
    else
      {:error, reason} -> mark_failed_result(dispatch, reason)
    end
  end

  defp travel(dispatch) do
    started_at = dispatch.en_route_at || DateTime.utc_now()
    dispatch = Repairs.update!(dispatch, %{status: :en_route, en_route_at: started_at})
    Repairs.broadcast(dispatch.device_id, {:repair_status_updated, Repairs.to_map(dispatch)})
    wait_remaining(started_at, dispatch.travel_ms)
    {:ok, dispatch}
  end

  defp repair(dispatch) do
    arrived_at = dispatch.arrived_at || DateTime.utc_now()
    dispatch = Repairs.update!(dispatch, %{status: :repairing, arrived_at: arrived_at})
    Repairs.broadcast(dispatch.device_id, {:repair_status_updated, Repairs.to_map(dispatch)})
    wait_remaining(arrived_at, dispatch.repair_ms)
    {:ok, dispatch}
  end

  defp maybe_return_to_office(dispatch) do
    if Repairs.queued_after?(dispatch.id), do: :ok, else: return_to_office(dispatch)
  end

  defp return_to_office(dispatch) do
    started_at = dispatch.return_started_at || DateTime.utc_now()

    dispatch =
      Repairs.update!(dispatch, %{status: :returning, return_started_at: started_at})

    route = return_route(dispatch)
    Repairs.broadcast(dispatch.device_id, {:technician_returning, route})
    wait_remaining(started_at, dispatch.travel_ms)

    returned =
      Repairs.update!(dispatch, %{status: :returned, returned_at: DateTime.utc_now()})

    Repairs.broadcast(returned.device_id, {:technician_returned, return_route(returned)})
    :ok
  end

  defp return_route(dispatch) do
    %{
      id: "return-#{dispatch.id}",
      device_id: dispatch.device_id,
      status: :returning,
      origin: Repairs.to_map(dispatch).destination,
      destination: Repairs.office(),
      office: Repairs.office(),
      travel_ms: dispatch.travel_ms,
      repair_ms: 0,
      en_route_at: dispatch.return_started_at
    }
  end

  defp wait_remaining(started_at, duration_ms) do
    elapsed = DateTime.diff(DateTime.utc_now(), started_at, :millisecond)
    Process.sleep(max(duration_ms - elapsed, 0))
  end

  defp mark_failed(dispatch_id, error) do
    dispatch = Repairs.fetch!(dispatch_id)

    failed =
      Repairs.update!(dispatch, %{
        status: :failed,
        failed_at: DateTime.utc_now(),
        failure_reason: Exception.message(error)
      })

    Repairs.broadcast(
      dispatch.device_id,
      {:repair_failed, Map.put(Repairs.to_map(failed), :reason, Exception.message(error))}
    )
  rescue
    _error -> :ok
  end

  defp mark_failed_result(dispatch, reason) do
    message = inspect(reason)

    failed =
      Repairs.update!(dispatch, %{
        status: :failed,
        failed_at: DateTime.utc_now(),
        failure_reason: message
      })

    Repairs.broadcast(
      dispatch.device_id,
      {:repair_failed, Map.put(Repairs.to_map(failed), :reason, message)}
    )

    {:error, message}
  end
end
