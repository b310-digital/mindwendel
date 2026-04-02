defmodule Mindwendel.Benchmark.ClassificationRunner do
  @moduledoc """
  Orchestrates classification benchmark fixture execution.

  Makes direct LLM calls using the same clustering system prompt as the production
  IdeaClusteringService, but bypasses TokenTrackingService and the web layer so the
  benchmark can run as a standalone Mix task without a database.

  Supports prompt variants for A/B testing — currently using `:xml_structured`.
  """

  alias Mindwendel.AI.Config
  alias Mindwendel.Benchmark.ClassificationBenchmarkResult
  alias Mindwendel.Benchmark.ClassificationFixture
  alias Mindwendel.Benchmark.ClassificationFixtures
  alias Mindwendel.Benchmark.ClassificationGrader
  alias Mindwendel.Benchmark.Grader
  require Logger

  @variants [:xml_structured]

  @xml_structured_prompt """
                         <role>You are a semantic clustering engine for brainstorming sessions.</role>

                         <task>Assign each idea to the 1–3 most conceptually relevant labels from the provided list.</task>

                         <constraints>
                         - Prefer conceptual similarity over surface wording
                         - Avoid weak or purely keyword-based connections
                         - Use at most 5 distinct label IDs across all assignments
                         - Copy idea_id and label_ids verbatim from input; never invent or rename
                         </constraints>

                         <output_format>
                         {"assignments":[{"idea_id":"string","label_ids":["string"]}]}
                         Return valid JSON only — no markdown, no commentary.
                         </output_format>
                         """
                         |> String.trim()

  @doc "Returns all supported prompt variant atoms."
  @spec variants() :: [atom()]
  def variants, do: @variants

  @doc "Returns the system prompt for the given variant."
  @spec system_prompt(atom()) :: String.t()
  def system_prompt(:xml_structured), do: @xml_structured_prompt

  @doc """
  Runs all classification fixtures for the given variant and returns a list of
  ClassificationBenchmarkResult structs.

  Calls `progress_cb` with a status string after each fixture completes.
  """
  @spec run_all((String.t() -> any()), atom()) :: [ClassificationBenchmarkResult.t()]
  def run_all(progress_cb \\ fn _msg -> :ok end, variant \\ :xml_structured) do
    ai_config = Config.fetch_ai_config!()
    prompt = system_prompt(variant)

    ClassificationFixtures.all()
    |> Enum.map(fn fixture ->
      result = run_fixture(fixture, ai_config, prompt)
      progress_cb.(format_progress(result))
      result
    end)
  end

  @doc "Runs a single classification fixture with the given system prompt. Never raises — errors are captured in the result."
  @spec run_fixture(ClassificationFixture.t(), keyword(), String.t()) ::
          ClassificationBenchmarkResult.t()
  def run_fixture(%ClassificationFixture{} = fixture, ai_config, prompt \\ nil) do
    prompt = prompt || system_prompt(:xml_structured)
    start_ms = System.monotonic_time(:millisecond)

    {raw_output, error} = classify(fixture, ai_config, prompt)

    duration_ms = System.monotonic_time(:millisecond) - start_ms

    dimensions = [
      ClassificationGrader.grade_json_validity(raw_output),
      ClassificationGrader.grade_semantic_quality(fixture, raw_output),
      Grader.grade_duration(duration_ms)
    ]

    %ClassificationBenchmarkResult{
      fixture_id: fixture.id,
      fixture: fixture,
      raw_output: raw_output,
      duration_ms: duration_ms,
      error: error,
      dimensions: dimensions
    }
  end

  # --- Private ---

  defp classify(fixture, ai_config, system_prompt) do
    alias OpenaiEx.Chat.Completions

    language = language_name(fixture.language)
    labels_payload = Enum.map(fixture.labels, &%{"id" => &1.id, "name" => &1.name})
    ideas_payload = Enum.map(fixture.ideas, &%{"id" => &1.id, "text" => &1.text})

    user_content =
      Enum.join(
        [
          "Language: #{language}",
          "Brainstorming title: #{fixture.brainstorming_title}",
          "Available labels JSON (array of {\"id\", \"name\"}; reuse these ids for assignments): #{Jason.encode!(labels_payload)}",
          "Ideas JSON (array of {\"id\", \"text\"}; copy each id into assignments.idea_id): #{Jason.encode!(ideas_payload)}",
          "Keep the total number of distinct label ids across assignments at 5 or fewer and output JSON that conforms to the schema above—nothing else."
        ],
        "\n"
      )

    messages = [
      %{"role" => "system", "content" => system_prompt},
      %{"role" => "user", "content" => user_content}
    ]

    client = build_openai_client(ai_config)

    chat_req =
      Completions.new(
        model: ai_config[:model],
        messages: messages,
        temperature: 0.0,
        max_tokens: 800,
        response_format: %{"type" => "json_object"}
      )

    case Completions.create(client, chat_req) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {content, nil}

      {:error, reason} ->
        Logger.warning(
          "Classification benchmark LLM call failed for #{fixture.id}: #{inspect(reason)}"
        )

        {nil, "LLM request failed: #{inspect(reason)}"}
    end
  rescue
    e -> {nil, "Exception: #{Exception.message(e)}"}
  catch
    kind, value -> {nil, "Caught #{kind}: #{inspect(value)}"}
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

  defp format_progress(
         %ClassificationBenchmarkResult{fixture_id: id, duration_ms: ms, error: nil} = r
       ) do
    scores = Enum.map_join(r.dimensions, "  ", fn d -> "#{d.name}=#{d.score}" end)
    "[OK]   #{id} (#{ms}ms)  #{scores}"
  end

  defp format_progress(%ClassificationBenchmarkResult{
         fixture_id: id,
         duration_ms: ms,
         error: err
       }) do
    "[ERR]  #{id} (#{ms}ms)  #{String.slice(err, 0, 80)}"
  end
end
