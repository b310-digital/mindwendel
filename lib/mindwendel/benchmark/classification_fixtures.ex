defmodule Mindwendel.Benchmark.ClassificationFixtures do
  alias Mindwendel.Benchmark.ClassificationFixture
  alias Mindwendel.Benchmark.ClassificationIdea
  alias Mindwendel.Benchmark.ClassificationLabel

  @doc "Returns all classification benchmark fixtures."
  @spec all() :: [ClassificationFixture.t()]
  def all do
    [
      # --- Fixture 1: Europäische Hauptstädte (DE) ---
      %ClassificationFixture{
        id: "classify-european-capitals-de",
        description:
          "German school geography quiz; tests classification of European capitals into geographic regions",
        brainstorming_title: "Europäische Hauptstädte",
        language: "de",
        labels: [
          %ClassificationLabel{id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", name: "Westeuropa"},
          %ClassificationLabel{id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaab", name: "Osteuropa"},
          %ClassificationLabel{id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaac", name: "Nordeuropa"},
          %ClassificationLabel{id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaad", name: "Südeuropa"}
        ],
        ideas: [
          %ClassificationIdea{id: "aaaaaaaa-aaaa-aaaa-aaaa-111111111101", text: "Paris"},
          %ClassificationIdea{id: "aaaaaaaa-aaaa-aaaa-aaaa-111111111102", text: "Warschau"},
          %ClassificationIdea{id: "aaaaaaaa-aaaa-aaaa-aaaa-111111111103", text: "Oslo"},
          %ClassificationIdea{id: "aaaaaaaa-aaaa-aaaa-aaaa-111111111104", text: "Madrid"},
          %ClassificationIdea{id: "aaaaaaaa-aaaa-aaaa-aaaa-111111111105", text: "Wien"},
          %ClassificationIdea{id: "aaaaaaaa-aaaa-aaaa-aaaa-111111111106", text: "Budapest"}
        ]
      },
      # --- Fixture 2: Amerikanische Präsidenten (DE) ---
      %ClassificationFixture{
        id: "classify-us-presidents-de",
        description:
          "German school history quiz; tests classification of US presidents into party and era categories",
        brainstorming_title: "Amerikanische Präsidenten",
        language: "de",
        labels: [
          %ClassificationLabel{id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbba", name: "Demokraten"},
          %ClassificationLabel{id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1", name: "Republikaner"},
          %ClassificationLabel{id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2", name: "Gründerväter"},
          %ClassificationLabel{id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb3", name: "Moderne"}
        ],
        ideas: [
          %ClassificationIdea{
            id: "bbbbbbbb-bbbb-bbbb-bbbb-111111111101",
            text: "George Washington"
          },
          %ClassificationIdea{
            id: "bbbbbbbb-bbbb-bbbb-bbbb-111111111102",
            text: "Thomas Jefferson"
          },
          %ClassificationIdea{
            id: "bbbbbbbb-bbbb-bbbb-bbbb-111111111103",
            text: "Abraham Lincoln"
          },
          %ClassificationIdea{
            id: "bbbbbbbb-bbbb-bbbb-bbbb-111111111104",
            text: "Franklin D. Roosevelt"
          },
          %ClassificationIdea{
            id: "bbbbbbbb-bbbb-bbbb-bbbb-111111111105",
            text: "John F. Kennedy"
          },
          %ClassificationIdea{
            id: "bbbbbbbb-bbbb-bbbb-bbbb-111111111106",
            text: "Ronald Reagan"
          }
        ]
      },
      # --- Fixture 3: School Subjects (EN) ---
      %ClassificationFixture{
        id: "classify-school-subjects-en",
        description:
          "English school curriculum planning; tests classification of subjects into clearly distinct academic domains",
        brainstorming_title: "School Subjects for the New Curriculum",
        language: "en",
        labels: [
          %ClassificationLabel{
            id: "cccccccc-cccc-cccc-cccc-ccccccccccca",
            name: "Natural Sciences"
          },
          %ClassificationLabel{
            id: "cccccccc-cccc-cccc-cccc-ccccccccccc1",
            name: "Social Studies"
          },
          %ClassificationLabel{
            id: "cccccccc-cccc-cccc-cccc-ccccccccccc2",
            name: "Languages & Literature"
          },
          %ClassificationLabel{id: "cccccccc-cccc-cccc-cccc-ccccccccccc3", name: "Arts & Music"}
        ],
        ideas: [
          %ClassificationIdea{id: "cccccccc-cccc-cccc-cccc-111111111101", text: "Biology"},
          %ClassificationIdea{id: "cccccccc-cccc-cccc-cccc-111111111102", text: "Geography"},
          %ClassificationIdea{
            id: "cccccccc-cccc-cccc-cccc-111111111103",
            text: "Creative Writing"
          },
          %ClassificationIdea{id: "cccccccc-cccc-cccc-cccc-111111111104", text: "Chemistry"},
          %ClassificationIdea{id: "cccccccc-cccc-cccc-cccc-111111111105", text: "Music Theory"},
          %ClassificationIdea{id: "cccccccc-cccc-cccc-cccc-111111111106", text: "Civics"}
        ]
      }
    ]
  end
end
