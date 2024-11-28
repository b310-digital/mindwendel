defmodule Mindwendel.Brainstormings.BrainstormingTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  # should be aliases in data case
  alias Mindwendel.Factory

  # improve ecto sandbox/test warnings when just in a describe
  describe "freaking relationships and on_replace stuff" do
    test "oof" do
      labels = [
        %IdeaLabel{name: "cyan", color: "#0dcaf0", position_order: 0}
      ]

      brainstorming = Factory.insert!(:brainstorming, labels: labels)

      # make it break we forein kay constraint
      brainstorming_label_first = List.first(brainstorming.labels)

      Factory.insert!(:idea,
        brainstorming: brainstorming,
        idea_labels: [
          brainstorming_label_first
        ]
      )

      attrs = %{
        "labels" => %{
          "0" => %{
            "color" => "#0dcaf0",
            "name" => "cyan"
          }
        },
        "labels_drop" => ["0"],
        # 0? 1?
        "labels_sort" => ["0"]
      }

      assert length(brainstorming.labels) == 1

      IO.puts("\n\n\n\n\n\n")
      IO.puts("CHANGESET")
      IO.puts("\n\n\n\n\n\n")

      changeset = Brainstorming.changeset(brainstorming, attrs)

      IO.puts("\n\n\n\n\n\n")
      IO.puts("UPDATE")
      IO.puts("\n\n\n\n\n\n")

      # boomzies
      assert {:ok, new_brain} = Repo.update(changeset)

      assert Enum.empty?(new_brain.labels)
    end
  end
end
