defmodule SmartCityLamp.Workers.HeartbeatWorker do
  use Oban.Worker,
    queue: :monitoring,
    max_attempts: 3,
    unique: [period: 55, fields: [:worker], states: :incomplete]

  alias SmartCityLamp.Monitoring.HeartbeatChecker

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    _results = HeartbeatChecker.check_all()
    :ok
  end
end
