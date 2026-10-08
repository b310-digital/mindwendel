defmodule Mindwendel.RateLimiter do
  @moduledoc """
  Fixed-window rate limiter backed by ETS.

  Counters are kept per node, so in a cluster every node allows `limit` hits
  per window.
  """
  use GenServer

  @table __MODULE__
  @cleanup_interval :timer.minutes(1)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Counts a hit for `key` and returns `:ok` as long as there were at most `limit`
  hits in the current window of `window_ms` milliseconds, `{:error, :rate_limited}`
  otherwise.
  """
  def hit(key, limit, window_ms) do
    window = div(System.system_time(:millisecond), window_ms)
    expires_at = (window + 1) * window_ms
    count = :ets.update_counter(@table, {key, window}, 1, {{key, window}, 0, expires_at})

    if count <= limit, do: :ok, else: {:error, :rate_limited}
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, write_concurrency: true])
    schedule_cleanup()
    {:ok, nil}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:"=<", :"$1", now}], [true]}])
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, @cleanup_interval)
end
