defmodule Mindwendel.Benchmark.GradingDimension do
  @enforce_keys [:name, :score]
  defstruct [:name, :score, :strengths, :weaknesses]

  @type t :: %__MODULE__{
          name: String.t(),
          score: float(),
          strengths: String.t() | nil,
          weaknesses: String.t() | nil
        }
end

defmodule Mindwendel.Benchmark.BenchmarkResult do
  @enforce_keys [:fixture_id, :fixture, :duration_ms]
  defstruct [:fixture_id, :fixture, :raw_output, :duration_ms, :error, dimensions: []]

  @type t :: %__MODULE__{
          fixture_id: String.t(),
          fixture: Mindwendel.Benchmark.BenchmarkFixture.t(),
          raw_output: String.t() | nil,
          duration_ms: non_neg_integer(),
          error: String.t() | nil,
          dimensions: [Mindwendel.Benchmark.GradingDimension.t()]
        }
end

defmodule Mindwendel.Benchmark.GradingReport do
  @enforce_keys [:timestamp, :provider, :model, :system_prompt, :results]
  defstruct [
    :timestamp,
    :provider,
    :model,
    :system_prompt,
    :results,
    averages: %{},
    overall_average: 0.0
  ]

  @type t :: %__MODULE__{
          timestamp: String.t(),
          provider: String.t(),
          model: String.t(),
          system_prompt: String.t(),
          results: [Mindwendel.Benchmark.BenchmarkResult.t()],
          averages: %{String.t() => float()},
          overall_average: float()
        }
end

defmodule Mindwendel.Benchmark.ClassificationBenchmarkResult do
  @enforce_keys [:fixture_id, :fixture, :duration_ms]
  defstruct [:fixture_id, :fixture, :raw_output, :duration_ms, :error, dimensions: []]

  @type t :: %__MODULE__{
          fixture_id: String.t(),
          fixture: Mindwendel.Benchmark.ClassificationFixture.t(),
          raw_output: String.t() | nil,
          duration_ms: non_neg_integer(),
          error: String.t() | nil,
          dimensions: [Mindwendel.Benchmark.GradingDimension.t()]
        }
end

defmodule Mindwendel.Benchmark.ClassificationGradingReport do
  @enforce_keys [:timestamp, :provider, :model, :system_prompt, :results]
  defstruct [
    :timestamp,
    :provider,
    :model,
    :system_prompt,
    :results,
    averages: %{},
    overall_average: 0.0
  ]

  @type t :: %__MODULE__{
          timestamp: String.t(),
          provider: String.t(),
          model: String.t(),
          system_prompt: String.t(),
          results: [Mindwendel.Benchmark.ClassificationBenchmarkResult.t()],
          averages: %{String.t() => float()},
          overall_average: float()
        }
end

defmodule Mindwendel.Benchmark.Report do
  alias Mindwendel.Benchmark.{
    BenchmarkFixture,
    BenchmarkResult,
    ClassificationBenchmarkResult,
    ClassificationFixture,
    ClassificationGradingReport,
    GradingDimension,
    GradingReport
  }

  @doc "Writes the report as a pretty-printed JSON file. Returns {:ok, path} or {:error, reason}."
  @spec save(GradingReport.t()) :: {:ok, String.t()} | {:error, term()}
  def save(%GradingReport{} = report) do
    path = report_path(report.timestamp)
    File.mkdir_p!(Path.dirname(path))

    case File.write(path, Jason.encode!(to_map(report), pretty: true)) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Converts a GradingReport struct to a plain map for JSON encoding."
  @spec to_map(GradingReport.t()) :: map()
  def to_map(%GradingReport{} = r) do
    %{
      timestamp: r.timestamp,
      provider: r.provider,
      model: r.model,
      system_prompt: r.system_prompt,
      results: Enum.map(r.results, &result_to_map/1),
      averages: r.averages,
      overall_average: r.overall_average
    }
  end

  defp result_to_map(%BenchmarkResult{} = r) do
    %{
      fixture_id: r.fixture_id,
      fixture: fixture_to_map(r.fixture),
      raw_output: r.raw_output,
      duration_ms: r.duration_ms,
      error: r.error,
      dimensions: Enum.map(r.dimensions, &dimension_to_map/1)
    }
  end

  defp fixture_to_map(%BenchmarkFixture{} = f) do
    %{
      id: f.id,
      description: f.description,
      brainstorming_title: f.brainstorming_title,
      language: f.language,
      topic: f.topic
    }
  end

  defp dimension_to_map(%GradingDimension{} = d) do
    %{name: d.name, score: d.score, strengths: d.strengths, weaknesses: d.weaknesses}
  end

  @doc "Writes the classification report as a pretty-printed JSON file. Returns {:ok, path} or {:error, reason}."
  @spec save_classification(ClassificationGradingReport.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def save_classification(%ClassificationGradingReport{} = report, variant_name \\ "default") do
    path = classification_report_path(report.timestamp, variant_name)
    File.mkdir_p!(Path.dirname(path))

    case File.write(path, Jason.encode!(classification_report_to_map(report), pretty: true)) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Converts a ClassificationGradingReport struct to a plain map for JSON encoding."
  @spec classification_report_to_map(ClassificationGradingReport.t()) :: map()
  def classification_report_to_map(%ClassificationGradingReport{} = r) do
    %{
      timestamp: r.timestamp,
      provider: r.provider,
      model: r.model,
      system_prompt: r.system_prompt,
      results: Enum.map(r.results, &classification_result_to_map/1),
      averages: r.averages,
      overall_average: r.overall_average
    }
  end

  defp classification_result_to_map(%ClassificationBenchmarkResult{} = r) do
    %{
      fixture_id: r.fixture_id,
      fixture: classification_fixture_to_map(r.fixture),
      raw_output: r.raw_output,
      duration_ms: r.duration_ms,
      error: r.error,
      dimensions: Enum.map(r.dimensions, &dimension_to_map/1)
    }
  end

  defp classification_fixture_to_map(%ClassificationFixture{} = f) do
    %{
      id: f.id,
      description: f.description,
      brainstorming_title: f.brainstorming_title,
      language: f.language,
      labels: Enum.map(f.labels, &%{id: &1.id, name: &1.name}),
      ideas: Enum.map(f.ideas, &%{id: &1.id, text: &1.text})
    }
  end

  defp report_path(timestamp) do
    safe_ts = String.replace(timestamp, ":", "-")
    Path.join(["benchmark", "reports", "#{safe_ts}.json"])
  end

  defp classification_report_path(timestamp, variant_name) do
    safe_ts = String.replace(timestamp, ":", "-")
    Path.join(["benchmark", "reports", "#{safe_ts}-classification-#{variant_name}.json"])
  end
end
