defmodule Mindwendel.Benchmark.ClassificationGrader do
  @moduledoc """
  Grades classification benchmark results on two independent dimensions:

  - `grade_json_validity/1`    — static check using the IdeaLabelAssignment schema (no API call)
  - `grade_semantic_quality/2` — LLM-as-judge using the same configured AI provider
  """

  alias Mindwendel.AI.Config
  alias Mindwendel.AI.Schemas.IdeaLabelAssignment
  alias Mindwendel.Benchmark.ClassificationFixture
  alias Mindwendel.Benchmark.GradingDimension

  require Logger

  @doc """
  Grades JSON validity of a raw classification output string.

  Expects `{"assignments": [{"idea_id": "...", "label_ids": ["..."]}]}`.
  Score is proportional: 10.0 when all assignments are valid, 0.0 when none are.
  """
  @spec grade_json_validity(String.t() | nil) :: GradingDimension.t()
  def grade_json_validity(nil) do
    %GradingDimension{
      name: "json_validity",
      score: 0.0,
      strengths: nil,
      weaknesses: "No output — generation failed before any response was received"
    }
  end

  def grade_json_validity(raw_output) when is_binary(raw_output) do
    cleaned = strip_markdown_fences(raw_output)

    case Jason.decode(cleaned) do
      {:error, decode_error} ->
        %GradingDimension{
          name: "json_validity",
          score: 0.0,
          strengths: nil,
          weaknesses: "JSON decode failed: #{inspect(decode_error)}"
        }

      {:ok, data} when not is_map(data) ->
        %GradingDimension{
          name: "json_validity",
          score: 0.0,
          strengths: nil,
          weaknesses: "Expected a JSON object at the top level, got: #{json_preview(data)}"
        }

      {:ok, %{"assignments" => assignments}} when is_list(assignments) and assignments != [] ->
        score_assignments(assignments)

      {:ok, %{"assignments" => []}} ->
        %GradingDimension{
          name: "json_validity",
          score: 0.0,
          strengths: nil,
          weaknesses: "Empty assignments array"
        }

      {:ok, _} ->
        %GradingDimension{
          name: "json_validity",
          score: 0.0,
          strengths: nil,
          weaknesses: "Missing or invalid 'assignments' key in response object"
        }
    end
  end

  @doc """
  Grades semantic quality of classification results by calling the configured LLM with a judge prompt.

  Returns a GradingDimension struct. Falls back to score 0.0 with an error
  message if the API call or response parsing fails.
  """
  @spec grade_semantic_quality(ClassificationFixture.t(), String.t() | nil) ::
          GradingDimension.t()
  def grade_semantic_quality(%ClassificationFixture{} = fixture, raw_output) do
    ai_config = Config.fetch_ai_config!()

    case call_judge_llm(fixture, raw_output, ai_config) do
      {:ok, response_text} ->
        parse_judge_response(response_text)

      {:error, reason} ->
        Logger.warning("Classification semantic grader LLM call failed: #{inspect(reason)}")

        %GradingDimension{
          name: "semantic_quality",
          score: 0.0,
          strengths: nil,
          weaknesses: "Semantic grading failed: #{inspect(reason)}"
        }
    end
  end

  # --- Private ---

  defp score_assignments(assignments_data) do
    {passed, failures} =
      assignments_data
      |> Enum.with_index()
      |> Enum.reduce({0, []}, fn {assignment, idx}, acc ->
        validate_assignment(assignment, idx, acc)
      end)

    score_summary(passed, length(assignments_data), failures)
  end

  defp validate_assignment(assignment, idx, {count, msgs}) do
    cs = IdeaLabelAssignment.changeset(%IdeaLabelAssignment{}, assignment)

    if cs.valid? do
      {count + 1, msgs}
    else
      errors = cs |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end) |> inspect()
      {count, msgs ++ ["assignment[#{idx}]: #{errors}"]}
    end
  end

  defp score_summary(passed, total, failures) do
    %GradingDimension{
      name: "json_validity",
      score: Float.round(passed / total * 10.0, 2),
      strengths:
        if(passed > 0,
          do: "#{passed}/#{total} assignments passed schema validation",
          else: nil
        ),
      weaknesses: if(failures != [], do: Enum.join(failures, "; "), else: nil)
    }
  end

  defp call_judge_llm(fixture, raw_output, ai_config) do
    alias OpenaiEx.Chat.Completions

    messages = [
      %{"role" => "system", "content" => judge_system_prompt()},
      %{"role" => "user", "content" => judge_user_prompt(fixture, raw_output)}
    ]

    client = build_openai_client(ai_config)

    chat_req =
      Completions.new(
        model: ai_config[:model],
        messages: messages,
        temperature: 0.0,
        max_tokens: 200
      )

    case Completions.create(client, chat_req) do
      {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
        {:ok, content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp judge_system_prompt do
    """
    You are an impartial evaluator of AI-generated idea-to-label assignments.
    Respond ONLY with valid JSON — no markdown, no commentary outside the JSON.
    Schema: {"score": <integer 0-10>, "strengths": "<one sentence>", "weaknesses": "<one sentence>"}
    """
  end

  defp judge_user_prompt(%ClassificationFixture{} = fixture, raw_output) do
    label_names = Enum.map_join(fixture.labels, ", ", & &1.name)
    idea_texts = Enum.map_join(fixture.ideas, "\n", &"- #{&1.text}")

    output_text = raw_output || "(no output — classification failed)"

    """
    Brainstorming title: #{fixture.brainstorming_title}
    Available labels: #{label_names}
    Ideas to classify:
    #{idea_texts}

    AI classification output (JSON):
    #{output_text}

    Evaluate the classification on these criteria:
    1. Correctness — Are ideas assigned to the most semantically appropriate labels?
    2. Completeness — Are all (or most) ideas assigned?
    3. Label coverage — Are the available labels used appropriately without over-assignment?

    Score from 0 (completely wrong) to 10 (excellent).
    Provide one sentence of strengths and one sentence of weaknesses.
    """
  end

  defp parse_judge_response(text) do
    cleaned = strip_markdown_fences(text)

    case Jason.decode(cleaned) do
      {:ok, %{"score" => score, "strengths" => strengths, "weaknesses" => weaknesses}}
      when is_number(score) ->
        %GradingDimension{
          name: "semantic_quality",
          score: Float.round(min(10.0, max(0.0, score / 1.0)), 2),
          strengths: strengths,
          weaknesses: weaknesses
        }

      {:ok, other} ->
        %GradingDimension{
          name: "semantic_quality",
          score: 0.0,
          strengths: nil,
          weaknesses: "Judge returned unexpected shape: #{json_preview(other)}"
        }

      {:error, err} ->
        %GradingDimension{
          name: "semantic_quality",
          score: 0.0,
          strengths: nil,
          weaknesses:
            "Could not parse judge JSON: #{inspect(err)}. Raw: #{String.slice(text, 0, 200)}"
        }
    end
  end

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

  defp strip_markdown_fences(text) do
    text
    |> String.trim()
    |> String.replace(~r/^```(?:json)?\s*\n?/, "")
    |> String.replace(~r/\n?```\s*$/, "")
    |> String.trim()
  end

  defp json_preview(data) do
    data |> Jason.encode!() |> String.slice(0, 80)
  end
end
