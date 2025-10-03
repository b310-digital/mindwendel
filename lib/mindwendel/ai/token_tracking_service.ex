defmodule Mindwendel.AI.TokenTrackingService do
  @moduledoc """
  Service for tracking AI token usage with hourly and daily limits.

  Provides functionality to:
  - Track token usage from LLM responses
  - Enforce hourly and daily token limits
  - Reset counters at configured times
  - Query usage statistics
  """

  import Ecto.Query
  alias Mindwendel.Repo
  alias Mindwendel.AI.TokenUsage

  require Logger

  @doc """
  Checks if a request can be made based on current usage limits.

  Returns {:ok, :allowed} if within limits, {:error, reason} otherwise.

  ## Soft Limits

  Note: This implements "soft" limits. Due to the check-then-act pattern,
  concurrent requests may both pass the limit check before either records usage,
  potentially causing limits to be slightly exceeded. This is acceptable for
  cost management purposes but not suitable for hard rate limiting.

  If strict enforcement is required, consider implementing database-level
  locks or using a reservation system.
  """
  @spec check_limits() ::
          {:ok, :allowed} | {:error, :daily_limit_exceeded | :hourly_limit_exceeded}
  def check_limits do
    config = fetch_ai_config!()

    with {:ok, daily_usage} <- get_current_daily_usage(),
         {:ok, hourly_usage} <- get_current_hourly_usage(),
         :ok <- check_daily_limit(daily_usage, config[:token_limit_daily]),
         :ok <- check_hourly_limit(hourly_usage, config[:token_limit_hourly]) do
      {:ok, :allowed}
    else
      {:error, _} = error -> error
    end
  end

  @doc """
  Records token usage from an LLM response.

  ## Parameters
    - usage_data: Map with :input_tokens, :output_tokens, :total_tokens
  """
  @spec record_usage(map()) :: {:ok, {TokenUsage.t(), TokenUsage.t()}} | {:error, term()}
  def record_usage(usage_data) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      daily = upsert_usage("daily", get_daily_period_start(now), usage_data)
      hourly = upsert_usage("hourly", get_hourly_period_start(now), usage_data)
      {daily, hourly}
    end)
  end

  @doc """
  Gets current daily usage statistics.
  """
  @spec get_current_daily_usage() :: {:ok, TokenUsage.t() | nil}
  def get_current_daily_usage do
    now = DateTime.utc_now()
    period_start = get_daily_period_start(now)

    usage =
      TokenUsage
      |> where([u], u.period_type == "daily" and u.period_start == ^period_start)
      |> Repo.one()

    {:ok, usage}
  end

  @doc """
  Gets current hourly usage statistics.
  """
  @spec get_current_hourly_usage() :: {:ok, TokenUsage.t() | nil}
  def get_current_hourly_usage do
    now = DateTime.utc_now()
    period_start = get_hourly_period_start(now)

    usage =
      TokenUsage
      |> where([u], u.period_type == "hourly" and u.period_start == ^period_start)
      |> Repo.one()

    {:ok, usage}
  end

  @doc """
  Cleans up old usage records (older than 90 days).
  """
  @spec cleanup_old_records() :: {:ok, integer()}
  def cleanup_old_records do
    cutoff = DateTime.utc_now() |> DateTime.add(-90, :day)

    {count, _} =
      TokenUsage
      |> where([u], u.period_start < ^cutoff)
      |> Repo.delete_all()

    {:ok, count}
  end

  # Private functions

  defp upsert_usage(period_type, period_start, usage_data) do
    input_tokens = usage_data[:input_tokens] || 0
    output_tokens = usage_data[:output_tokens] || 0
    total_tokens = usage_data[:total_tokens] || 0

    existing =
      TokenUsage
      |> where([u], u.period_type == ^period_type and u.period_start == ^period_start)
      |> Repo.one()

    do_upsert(
      existing,
      period_type,
      period_start,
      {input_tokens, output_tokens, total_tokens}
    )
  end

  defp do_upsert(
         nil,
         period_type,
         period_start,
         {input_tokens, output_tokens, total_tokens}
       ) do
    attrs = %{
      period_type: period_type,
      period_start: period_start,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      total_tokens: total_tokens,
      request_count: 1
    }

    TokenUsage.changeset(%TokenUsage{}, attrs) |> Repo.insert!()
  end

  defp do_upsert(
         record,
         _period_type,
         _period_start,
         {input_tokens, output_tokens, total_tokens}
       ) do
    updated_attrs = %{
      input_tokens: record.input_tokens + input_tokens,
      output_tokens: record.output_tokens + output_tokens,
      total_tokens: record.total_tokens + total_tokens,
      request_count: record.request_count + 1
    }

    TokenUsage.changeset(record, updated_attrs) |> Repo.update!()
  end

  defp check_daily_limit(nil, _limit), do: :ok
  defp check_daily_limit(_usage, nil), do: :ok

  defp check_daily_limit(usage, limit) when usage.total_tokens >= limit do
    {:error, :daily_limit_exceeded}
  end

  defp check_daily_limit(_usage, _limit), do: :ok

  defp check_hourly_limit(nil, _limit), do: :ok
  defp check_hourly_limit(_usage, nil), do: :ok

  defp check_hourly_limit(usage, limit) when usage.total_tokens >= limit do
    {:error, :hourly_limit_exceeded}
  end

  defp check_hourly_limit(_usage, _limit), do: :ok

  defp get_daily_period_start(datetime) do
    config = fetch_ai_config!()
    reset_hour = config[:token_reset_hour] || 0

    datetime
    |> DateTime.to_date()
    |> DateTime.new!(Time.new!(reset_hour, 0, 0))
    |> DateTime.truncate(:second)
  end

  defp get_hourly_period_start(datetime) do
    %{datetime | minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp fetch_ai_config! do
    Application.fetch_env!(:mindwendel, :ai)
  end
end
