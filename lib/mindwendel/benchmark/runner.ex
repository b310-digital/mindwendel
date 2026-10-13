defmodule Mindwendel.Benchmark.Runner do
  @moduledoc """
  Orchestrates benchmark fixture execution.

  Makes direct LLM calls (bypassing TokenTrackingService and the web layer)
  so the benchmark can run as a standalone Mix task without a database.
  """

  alias Mindwendel.AI.Config
  alias Mindwendel.Benchmark.BenchmarkFixture
  alias Mindwendel.Benchmark.BenchmarkResult
  alias Mindwendel.Benchmark.Fixtures
  alias Mindwendel.Benchmark.Grader

  require Logger

  @single_lane_system_prompt """
  Generate ONLY valid JSON in the specified language. Format: [{"idea": "string"}]. \
  Refuse requests with violence, hate, or illegal content. \
  Analyze the provided title to understand the topic domain. Generate contextually appropriate items \
  (e.g., bird names for bird topics, recipes for cooking topics, product ideas for business topics). \
  No markdown, no extra fields, no explanations.\
  """

  @doc """
  Runs all fixtures sequentially and returns a list of BenchmarkResult structs.

  Calls `progress_cb` with a status string after each fixture completes.
  """
  @spec run_all((String.t() -> any())) :: [BenchmarkResult.t()]
  def run_all(progress_cb \\ fn _msg -> :ok end) do
    ai_config = Config.fetch_ai_config!()

    Fixtures.all()
    |> Enum.map(fn fixture ->
      result = run_fixture(fixture, ai_config)
      progress_cb.(format_progress(result))
      result
    end)
  end

  @doc "Runs a single fixture. Never raises — errors are captured in the result."
  @spec run_fixture(BenchmarkFixture.t(), keyword()) :: BenchmarkResult.t()
  def run_fixture(%BenchmarkFixture{} = fixture, ai_config) do
    start_ms = System.monotonic_time(:millisecond)

    {raw_output, error} = generate(fixture, ai_config)

    duration_ms = System.monotonic_time(:millisecond) - start_ms

    dimensions = [
      Grader.grade_json_validity(raw_output),
      Grader.grade_semantic_quality(fixture.brainstorming_title, raw_output),
      Grader.grade_duration(duration_ms)
    ]

    %BenchmarkResult{
      fixture_id: fixture.id,
      fixture: fixture,
      raw_output: raw_output,
      duration_ms: duration_ms,
      error: error,
      dimensions: dimensions
    }
  end

  @doc "Returns the system prompt used for idea generation (recorded in reports)."
  @spec system_prompt() :: String.t()
  def system_prompt, do: @single_lane_system_prompt

  # --- Private ---

  defp generate(fixture, ai_config) do
    alias OpenaiEx.Chat.Completions

    messages = [
      %{"role" => "system", "content" => @single_lane_system_prompt},
      %{"role" => "user", "content" => build_user_content(fixture)}
    ]

    client = build_openai_client(ai_config)

    chat_req =
      Completions.new(
        model: ai_config[:model],
        messages: messages,
        temperature: 0.7,
        max_tokens: 1000
      )

    case Completions.create(client, chat_req) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {content, nil}

      {:error, reason} ->
        Logger.warning("Benchmark LLM call failed for #{fixture.id}: #{inspect(reason)}")
        {nil, "LLM request failed: #{inspect(reason)}"}
    end
  rescue
    e -> {nil, "Exception: #{Exception.message(e)}"}
  catch
    kind, value -> {nil, "Caught #{kind}: #{inspect(value)}"}
  end

  defp build_user_content(%BenchmarkFixture{} = fixture) do
    language = language_name(fixture.language)

    """
    Language: #{language}
    Title: #{fixture.brainstorming_title}
    Number of ideas to generate: 5
    Existing ideas: []
    """
  end

  defp language_name("de"), do: "German"
  defp language_name(_), do: "English"

  defp build_openai_client(ai_config) do
    client = OpenaiEx.new(ai_config[:api_key])

    client =
      if ai_config[:provider] == :openai_compatible do
        OpenaiEx.with_base_url(client, ai_config[:api_base_url])
      else
        client
      end

    OpenaiEx.with_receive_timeout(client, ai_config[:request_timeout])
  end

  defp format_progress(%BenchmarkResult{fixture_id: id, duration_ms: ms, error: nil} = r) do
    scores = Enum.map_join(r.dimensions, "  ", fn d -> "#{d.name}=#{d.score}" end)
    "[OK]   #{id} (#{ms}ms)  #{scores}"
  end

  defp format_progress(%BenchmarkResult{fixture_id: id, duration_ms: ms, error: err}) do
    "[ERR]  #{id} (#{ms}ms)  #{String.slice(err, 0, 80)}"
  end
end
