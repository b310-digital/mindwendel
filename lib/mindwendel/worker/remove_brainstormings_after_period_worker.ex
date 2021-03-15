defmodule Mindwendel.Worker.RemoveBrainstormingsAfterPeriodWorker do
  use Oban.Worker, unique: [fields: [:worker], period: 60]
  alias Mindwendel.Brainstormings

  @impl Oban.Worker
  def perform(_job) do
    days =
      Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]

    Brainstormings.delete_old_brainstormings(days)

    :ok
  end
end
