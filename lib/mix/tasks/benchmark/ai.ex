defmodule Mix.Tasks.Benchmark.Ai do
  use Mix.Task

  alias Mindwendel.AI.Config

  alias Mindwendel.Benchmark.{
    ClassificationFixtures,
    ClassificationGradingReport,
    ClassificationRunner,
    Fixtures,
    GradingReport,
    Report,
    Runner
  }

  @shortdoc "Runs the AI idea-generation and classification benchmark suites"

  @moduledoc """
  Runs benchmark suites that evaluate Mindwendel's AI features.

  By default both suites run. Use `--only` to run a single suite.

  ## Usage

      MW_AI_ENABLED=true MW_AI_API_KEY=sk-... MW_AI_API_MODEL=gpt-4o-mini mix benchmark.ai
      mix benchmark.ai --only generation
      mix benchmark.ai --only classification

  ## Options

    - `--only generation`     — run only the idea-generation suite (#{length(Fixtures.all())} fixtures)
    - `--only classification` — run only the classification suite (#{length(ClassificationFixtures.all())} fixtures)

  ## Required environment variables

    - `MW_AI_ENABLED=true`
    - `MW_AI_API_KEY`      — API key for the LLM provider
    - `MW_AI_API_MODEL`    — Model name (default: `gpt-4o-mini`)
    - `MW_AI_API_BASE_URL` — Required only for OpenAI-compatible providers
  """

  @valid_suites ~w(generation classification)

  @impl Mix.Task
  def run(args) do
    # credo:disable-for-next-line Credo.Check.Warning.MixEnv
    if Mix.env() == :prod do
      Mix.raise("mix benchmark.ai cannot be run in the production environment.")
    end

    {opts, _} = OptionParser.parse!(args, strict: [only: :string])
    suite = Keyword.get(opts, :only)

    if suite && suite not in @valid_suites do
      Mix.raise(
        "Unknown suite #{inspect(suite)}. Valid values: #{Enum.join(@valid_suites, ", ")}"
      )
    end

    Mix.Task.run("app.config")
    Application.ensure_all_started(:openai_ex)

    ai_config = Config.fetch_ai_config!()

    unless ai_config[:enabled] do
      Mix.raise("""
      AI is not enabled. Set MW_AI_ENABLED=true and provide API credentials.
      Run `mix help benchmark.ai` for the full list of required environment variables.
      """)
    end

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    if suite in [nil, "generation"], do: run_generation_suite(ai_config, timestamp)
    if suite in [nil, "classification"], do: run_classification_suite(ai_config, timestamp)
  end

  # --- Private ---

  defp run_generation_suite(ai_config, timestamp) do
    Mix.shell().info(generation_banner(ai_config, timestamp))

    results = Runner.run_all(fn msg -> Mix.shell().info(msg) end)

    report = %GradingReport{
      timestamp: timestamp,
      provider: to_string(ai_config[:provider]),
      model: ai_config[:model],
      system_prompt: Runner.system_prompt(),
      results: results,
      averages: compute_averages(results),
      overall_average: compute_overall_average(results)
    }

    case Report.save(report) do
      {:ok, path} -> Mix.shell().info("\nReport saved to: #{path}")
      {:error, reason} -> Mix.shell().error("Failed to save report: #{inspect(reason)}")
    end

    print_summary(report, "Idea Generation Results")
  end

  defp run_classification_suite(ai_config, timestamp) do
    Enum.each(ClassificationRunner.variants(), fn variant ->
      variant_name = to_string(variant)
      Mix.shell().info(classification_banner(ai_config, variant_name))

      results =
        ClassificationRunner.run_all(fn msg -> Mix.shell().info(msg) end, variant)

      report = %ClassificationGradingReport{
        timestamp: timestamp,
        provider: to_string(ai_config[:provider]),
        model: ai_config[:model],
        system_prompt: ClassificationRunner.system_prompt(variant),
        results: results,
        averages: compute_averages(results),
        overall_average: compute_overall_average(results)
      }

      case Report.save_classification(report, variant_name) do
        {:ok, path} ->
          Mix.shell().info("\nClassification report saved to: #{path}")

        {:error, reason} ->
          Mix.shell().error("Failed to save classification report: #{inspect(reason)}")
      end

      print_summary(report, "Classification Results [#{variant_name}]")
    end)
  end

  defp generation_banner(ai_config, timestamp) do
    """
    ====================================
    Mindwendel AI Benchmark
    ====================================
    Provider : #{ai_config[:provider]}
    Model    : #{ai_config[:model]}
    Timestamp: #{timestamp}
    ====================================
    [1/2] Idea Generation (#{length(Fixtures.all())} fixtures)
    ------------------------------------
    """
  end

  defp classification_banner(ai_config, variant_name) do
    """
    ------------------------------------
    [2/2] Classification (#{length(ClassificationFixtures.all())} fixtures) — variant: #{variant_name}
    Provider : #{ai_config[:provider]}
    Model    : #{ai_config[:model]}
    ------------------------------------
    """
  end

  defp compute_averages(results) do
    all_dims = Enum.flat_map(results, & &1.dimensions)
    names = all_dims |> Enum.map(& &1.name) |> Enum.uniq()

    Map.new(names, fn name ->
      scores = all_dims |> Enum.filter(&(&1.name == name)) |> Enum.map(& &1.score)
      {name, Float.round(Enum.sum(scores) / length(scores), 2)}
    end)
  end

  defp compute_overall_average(results) do
    scores = results |> Enum.flat_map(& &1.dimensions) |> Enum.map(& &1.score)
    if scores == [], do: 0.0, else: Float.round(Enum.sum(scores) / length(scores), 2)
  end

  defp print_summary(report, title) do
    col1 = 42
    col2 = 15
    col3 = 18
    col4 = 8
    col5 = 10
    sep = String.duplicate("-", col1 + col2 + col3 + col4 + col5)

    Mix.shell().info("\n#{title}")
    Mix.shell().info(sep)

    Mix.shell().info(
      String.pad_trailing("Fixture ID", col1) <>
        String.pad_leading("json_validity", col2) <>
        String.pad_leading("semantic_quality", col3) <>
        String.pad_leading("speed", col4) <>
        String.pad_leading("dur(ms)", col5)
    )

    Mix.shell().info(sep)

    Enum.each(report.results, fn r ->
      label = if r.error, do: r.fixture_id <> " [ERR]", else: r.fixture_id
      jv = format_score(get_score(r, "json_validity"))
      sq = format_score(get_score(r, "semantic_quality"))
      sp = format_score(get_score(r, "speed"))

      Mix.shell().info(
        String.pad_trailing(label, col1) <>
          String.pad_leading(jv, col2) <>
          String.pad_leading(sq, col3) <>
          String.pad_leading(sp, col4) <>
          String.pad_leading(to_string(r.duration_ms), col5)
      )
    end)

    Mix.shell().info(sep)

    Mix.shell().info("""

    Averages:
      json_validity    : #{Map.get(report.averages, "json_validity", 0.0)}
      semantic_quality : #{Map.get(report.averages, "semantic_quality", 0.0)}
      speed            : #{Map.get(report.averages, "speed", 0.0)}
      overall          : #{report.overall_average}
    """)
  end

  defp get_score(%{dimensions: dims}, name) do
    case Enum.find(dims, &(&1.name == name)) do
      nil -> nil
      d -> d.score
    end
  end

  defp format_score(nil), do: "N/A"
  defp format_score(score), do: :erlang.float_to_binary(score, decimals: 2)
end
