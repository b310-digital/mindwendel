defmodule Mindwendel.Benchmark.Grader do
  @moduledoc """
  Grades benchmark results on three independent dimensions:

  - `grade_json_validity/1` — static check using the existing IdeaResponse schema (no API call)
  - `grade_semantic_quality/2` — LLM-as-judge using the same configured AI provider
  - `grade_duration/1` — pure latency score; no API call
  """

  alias Mindwendel.AI.Config
  alias Mindwendel.AI.Schemas.IdeaResponse
  alias Mindwendel.Benchmark.GradingDimension

  require Logger

  @doc """
  Grades JSON validity of a raw output string.

  Uses `IdeaResponse.changeset/2` for each idea — purely static, no API call.
  Score is proportional: 10.0 when all ideas are valid, 0.0 when none are.
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

      {:ok, data} when not is_list(data) ->
        %GradingDimension{
          name: "json_validity",
          score: 0.0,
          strengths: nil,
          weaknesses: "Expected a JSON array at the top level, got: #{json_preview(data)}"
        }

      {:ok, []} ->
        %GradingDimension{
          name: "json_validity",
          score: 0.0,
          strengths: nil,
          weaknesses: "Response was an empty array"
        }

      {:ok, ideas_data} when is_list(ideas_data) ->
        score_ideas(ideas_data)
    end
  end

  @doc """
  Grades semantic quality by calling the configured LLM with a judge prompt.

  Returns a GradingDimension struct. Falls back to score 0.0 with an error
  message if the API call or response parsing fails.
  """
  @spec grade_semantic_quality(String.t(), String.t() | nil) :: GradingDimension.t()
  def grade_semantic_quality(brainstorming_title, raw_output) do
    ai_config = Config.fetch_ai_config!()

    case call_judge_llm(brainstorming_title, raw_output, ai_config) do
      {:ok, response_text} ->
        parse_judge_response(response_text)

      {:error, reason} ->
        Logger.warning("Semantic grader LLM call failed: #{inspect(reason)}")

        %GradingDimension{
          name: "semantic_quality",
          score: 0.0,
          strengths: nil,
          weaknesses: "Semantic grading failed: #{inspect(reason)}"
        }
    end
  end

  # --- Private ---

  defp score_ideas(ideas_data) do
    {passed, failures} =
      ideas_data
      |> Enum.with_index()
      |> Enum.reduce({0, []}, fn {idea, idx}, acc -> validate_idea(idea, idx, acc) end)

    score_summary(passed, length(ideas_data), failures)
  end

  defp validate_idea(idea, idx, {count, msgs}) do
    cs = IdeaResponse.changeset(%IdeaResponse{}, idea)

    if cs.valid? do
      {count + 1, msgs}
    else
      errors = cs |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end) |> inspect()
      {count, msgs ++ ["idea[#{idx}]: #{errors}"]}
    end
  end

  defp score_summary(passed, total, failures) do
    %GradingDimension{
      name: "json_validity",
      score: Float.round(passed / total * 10.0, 2),
      strengths:
        if(passed > 0, do: "#{passed}/#{total} ideas passed schema validation", else: nil),
      weaknesses: if(failures != [], do: Enum.join(failures, "; "), else: nil)
    }
  end

  defp call_judge_llm(title, raw_output, ai_config) do
    alias OpenaiEx.Chat.Completions

    messages = [
      %{"role" => "system", "content" => judge_system_prompt()},
      %{"role" => "user", "content" => judge_user_prompt(title, raw_output)}
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
    You are an impartial evaluator of brainstorming idea lists.
    Respond ONLY with valid JSON — no markdown, no commentary outside the JSON.
    Schema: {"score": <integer 0-10>, "strengths": "<one sentence>", "weaknesses": "<one sentence>"}
    """
  end

  defp judge_user_prompt(title, raw_output) do
    output_text = raw_output || "(no output — generation failed)"

    """
    Brainstorming title: #{title}
    Generated ideas (JSON from AI):
    #{output_text}

    Evaluate on these criteria:
    1. Relevance — Are all ideas genuinely related to the title?
    2. Diversity — Are the ideas sufficiently distinct from one another (not repetitive)?
    3. Appropriateness — Are the ideas safe, sensible, and on-topic?

    Score from 0 (completely useless) to 10 (excellent).
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

  @doc """
  Grades the latency of the AI generation or classification call as a pure score — no API call.

  The `duration_ms` value must be the wall time of the LLM call itself only,
  measured before any grading runs (as is the case in both Runner and ClassificationRunner).

  Scores 10.0 for any response at or under 5 seconds.
  Loses 1 point for each additional second beyond that, floored at 0.0.

      ≤ 5 000 ms → 10.0
        6 000 ms →  9.0
       10 000 ms →  5.0
       15 000 ms →  0.0
  """
  @spec grade_duration(non_neg_integer()) :: GradingDimension.t()
  def grade_duration(duration_ms) when is_integer(duration_ms) and duration_ms >= 0 do
    score = Float.round(max(0.0, 10.0 - max(0.0, (duration_ms - 5000) / 1000.0)), 2)

    %GradingDimension{
      name: "speed",
      score: score,
      strengths:
        if(score >= 8.0, do: "Response within target latency (#{duration_ms}ms)", else: nil),
      weaknesses:
        if(score < 8.0, do: "Response took #{duration_ms}ms; target is ≤5000ms", else: nil)
    }
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
