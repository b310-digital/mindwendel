defmodule Mindwendel.Benchmark.ClassificationLabel do
  @enforce_keys [:id, :name]
  defstruct [:id, :name]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t()
        }
end

defmodule Mindwendel.Benchmark.ClassificationIdea do
  @enforce_keys [:id, :text]
  defstruct [:id, :text]

  @type t :: %__MODULE__{
          id: String.t(),
          text: String.t()
        }
end

defmodule Mindwendel.Benchmark.ClassificationFixture do
  @enforce_keys [:id, :description, :brainstorming_title, :language, :labels, :ideas]
  defstruct [:id, :description, :brainstorming_title, :language, :labels, :ideas]

  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t(),
          brainstorming_title: String.t(),
          language: String.t(),
          labels: [Mindwendel.Benchmark.ClassificationLabel.t()],
          ideas: [Mindwendel.Benchmark.ClassificationIdea.t()]
        }
end
