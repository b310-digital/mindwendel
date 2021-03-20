defmodule Mindwendel.Worker.RemoveBrainstormingsAndUsersAfterPeriodWorker do
  use Oban.Worker, unique: [fields: [:worker], period: 60]
  alias Mindwendel.Brainstormings
  alias Mindwendel.Accounts

  @impl Oban.Worker
  def perform(_job) do
    days =
      Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]

    Brainstormings.delete_old_brainstormings(days)
    Accounts.delete_inactive_users(days)

    :ok
  end
end
