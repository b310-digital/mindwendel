defmodule Mindwendel.Workers.AiTokenCleanupWorker do
  @moduledoc """
  Oban worker to clean up old AI token usage records.

  Runs daily to remove records older than 90 days.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Mindwendel.AI.TokenTrackingService

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case TokenTrackingService.cleanup_old_records() do
      {:ok, count} ->
        Logger.info("Cleaned up #{count} old AI token usage records")
        :ok

      {:error, reason} ->
        Logger.error("Failed to clean up AI token records: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
