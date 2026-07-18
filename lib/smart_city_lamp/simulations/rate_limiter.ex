defmodule SmartCityLamp.Simulations.RateLimiter do
  use GenServer

  @window_ms 60_000
  @session_limit 20
  @device_cooldown_ms 2_000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def check(rate_key, device_id), do: GenServer.call(__MODULE__, {:check, rate_key, device_id})
  def reset, do: GenServer.call(__MODULE__, :reset)

  @impl true
  def init(_opts), do: {:ok, %{sessions: %{}, devices: %{}}}

  @impl true
  def handle_call({:check, rate_key, device_id}, _from, state) do
    now = System.monotonic_time(:millisecond)
    timestamps = state.sessions |> Map.get(rate_key, []) |> Enum.filter(&(now - &1 < @window_ms))
    last_device_event = Map.get(state.devices, device_id)

    cond do
      length(timestamps) >= @session_limit ->
        {:reply, {:error, :rate_limit_exceeded}, put_in(state.sessions[rate_key], timestamps)}

      last_device_event && now - last_device_event < @device_cooldown_ms ->
        {:reply, {:error, :device_cooldown}, put_in(state.sessions[rate_key], timestamps)}

      true ->
        state =
          state
          |> put_in([:sessions, rate_key], [now | timestamps])
          |> put_in([:devices, device_id], now)

        {:reply, :ok, state}
    end
  end

  def handle_call(:reset, _from, _state), do: {:reply, :ok, %{sessions: %{}, devices: %{}}}
end
