defmodule Mindwendel.AI.TokenTrackingServiceTest do
  use Mindwendel.DataCase, async: false

  alias Mindwendel.AI.TokenTrackingService
  alias Mindwendel.AI.TokenUsage

  describe "record_usage/1" do
    test "creates new daily and hourly usage records" do
      usage_data = %{
        input_tokens: 100,
        output_tokens: 50,
        total_tokens: 150
      }

      assert {:ok, {daily, hourly}} = TokenTrackingService.record_usage(usage_data)
      assert daily.period_type == "daily"
      assert hourly.period_type == "hourly"
      assert daily.total_tokens == 150
      assert hourly.total_tokens == 150
    end

    test "increments existing usage records" do
      usage_data = %{
        input_tokens: 100,
        output_tokens: 50,
        total_tokens: 150
      }

      {:ok, _} = TokenTrackingService.record_usage(usage_data)
      {:ok, {daily, _}} = TokenTrackingService.record_usage(usage_data)

      assert daily.total_tokens == 300
      assert daily.request_count == 2
    end
  end

  describe "check_limits/0" do
    setup do
      # Mock config for test
      Application.put_env(:mindwendel, :ai,
        enabled: true,
        token_limit_daily: 1000,
        token_limit_hourly: 100,
        token_reset_hour: 0
      )

      on_exit(fn ->
        # Restore test config from config/test.exs
        Application.put_env(:mindwendel, :ai,
          enabled: false,
          token_limit_daily: nil,
          token_limit_hourly: nil
        )
      end)

      :ok
    end

    test "allows request when under limits" do
      assert {:ok, :allowed} = TokenTrackingService.check_limits()
    end

    test "blocks request when daily limit exceeded" do
      usage_data = %{total_tokens: 1001}
      {:ok, _} = TokenTrackingService.record_usage(usage_data)

      assert {:error, :daily_limit_exceeded} = TokenTrackingService.check_limits()
    end

    test "blocks request when hourly limit exceeded" do
      usage_data = %{total_tokens: 101}
      {:ok, _} = TokenTrackingService.record_usage(usage_data)

      assert {:error, :hourly_limit_exceeded} = TokenTrackingService.check_limits()
    end
  end

  describe "cleanup_old_records/0" do
    test "removes records older than 90 days" do
      # Create an old record
      old_date = DateTime.utc_now() |> DateTime.add(-91, :day)

      %TokenUsage{}
      |> TokenUsage.changeset(%{
        period_type: "daily",
        period_start: old_date,
        total_tokens: 100
      })
      |> Repo.insert!()

      # Create a recent record
      recent_date = DateTime.utc_now() |> DateTime.add(-1, :day)

      %TokenUsage{}
      |> TokenUsage.changeset(%{
        period_type: "daily",
        period_start: recent_date,
        total_tokens: 100
      })
      |> Repo.insert!()

      {:ok, count} = TokenTrackingService.cleanup_old_records()

      assert count == 1
      assert Repo.aggregate(TokenUsage, :count) == 1
    end
  end
end
