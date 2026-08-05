defmodule Mindwendel.Benchmark.BenchmarkFixture do
  @enforce_keys [:id, :description, :brainstorming_title, :language, :topic]
  defstruct [:id, :description, :brainstorming_title, :language, :topic]

  @type topic :: :informational | :technical | :creative | :edge_case

  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t(),
          brainstorming_title: String.t(),
          language: String.t(),
          topic: topic()
        }
end

defmodule Mindwendel.Benchmark.Fixtures do
  alias Mindwendel.Benchmark.BenchmarkFixture

  @doc "Returns all benchmark fixtures."
  @spec all() :: [BenchmarkFixture.t()]
  def all do
    [
      # --- Informational ---
      %BenchmarkFixture{
        id: "info-photosynthesis-en",
        description: "Broad science topic; expects varied biology and chemistry ideas",
        brainstorming_title: "Photosynthesis",
        language: "en",
        topic: :informational
      },
      %BenchmarkFixture{
        id: "info-photosynthesis-de",
        description: "Same science topic in German; tests locale handling",
        brainstorming_title: "Photosynthese",
        language: "de",
        topic: :informational
      },
      %BenchmarkFixture{
        id: "info-roman-empire-en",
        description: "Historical topic; expects diverse aspects of Roman civilization",
        brainstorming_title: "The Roman Empire",
        language: "en",
        topic: :informational
      },
      %BenchmarkFixture{
        id: "info-roman-empire-de",
        description: "Same historical topic in German",
        brainstorming_title: "Das Römische Reich",
        language: "de",
        topic: :informational
      },
      %BenchmarkFixture{
        id: "info-seven-wonders-de",
        description:
          "Well-known enumerable cultural topic in German; tests factual recall and German locale handling",
        brainstorming_title: "Die sieben Weltwunder",
        language: "de",
        topic: :informational
      },
      # --- Technical ---
      %BenchmarkFixture{
        id: "tech-microservices-en",
        description: "Software architecture topic; expects distinct architectural concepts",
        brainstorming_title: "Microservices architecture",
        language: "en",
        topic: :technical
      },
      %BenchmarkFixture{
        id: "tech-microservices-de",
        description: "Same technical topic in German",
        brainstorming_title: "Microservices-Architektur",
        language: "de",
        topic: :technical
      },
      %BenchmarkFixture{
        id: "tech-ml-pipelines-en",
        description: "ML engineering topic; expects distinct pipeline concepts",
        brainstorming_title: "Machine learning pipelines",
        language: "en",
        topic: :technical
      },
      %BenchmarkFixture{
        id: "tech-ml-pipelines-de",
        description: "ML pipelines in German",
        brainstorming_title: "Machine-Learning-Pipelines",
        language: "de",
        topic: :technical
      },
      # --- Creative ---
      %BenchmarkFixture{
        id: "creative-utopia-en",
        description: "Open-ended creative topic; high variance and originality expected",
        brainstorming_title: "A utopian city",
        language: "en",
        topic: :creative
      },
      %BenchmarkFixture{
        id: "creative-robot-book-de",
        description: "Children's book creative topic in German",
        brainstorming_title: "Ein Kinderbuch über Roboter",
        language: "de",
        topic: :creative
      },
      # --- Edge Cases ---
      %BenchmarkFixture{
        id: "edge-very-long-title-de",
        description: "Very long German title; tests robustness with verbose input",
        brainstorming_title:
          "Die Zukunft der erneuerbaren Energiequellen im Kontext des globalen Klimawandels und nachhaltiger Stadtentwicklung",
        language: "de",
        topic: :edge_case
      }
    ]
  end
end
