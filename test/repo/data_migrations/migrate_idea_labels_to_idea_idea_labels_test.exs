defmodule Mindwendel.Repo.DataMigrations.MigrateIdeaLabelsToIdeaIdeaLabelsTest do
  Code.require_file("./priv/repo/data_migrations/migrate_idea_labels_to_idea_idea_labels.exs")

  use Mindwendel.DataCase

  alias Mindwendel.Factory
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Repo.DataMigrations.MigrateIdeaLabelsToIdeaIdeaLabels

  setup do
    brainstorming = Factory.insert!(:brainstorming)
    brainstorming_label_1 = brainstorming.labels |> Enum.at(1)
    idea_1 = Factory.insert!(:idea, brainstorming: brainstorming, label: brainstorming_label_1)
    brainstorming_label_2 = brainstorming.labels |> Enum.at(2)
    idea_2 = Factory.insert!(:idea, brainstorming: brainstorming, label: brainstorming_label_2)

    %{
      brainstorming: brainstorming,
      brainstorming_label_1: brainstorming_label_1,
      idea_1: idea_1,
      brainstorming_label_2: brainstorming_label_2,
      idea_2: idea_2
    }
  end

  test "migrates successfully", %{
    brainstorming: _brainstorming,
    brainstorming_label_1: brainstorming_label_1,
    idea_1: idea_1,
    brainstorming_label_2: brainstorming_label_2,
    idea_2: idea_2
  } do
    assert Repo.all(Idea) |> Enum.count() == 2
    assert Enum.empty?(Repo.all(IdeaIdeaLabel))

    MigrateIdeaLabelsToIdeaIdeaLabels.run()

    assert Repo.all(IdeaIdeaLabel) |> Enum.count() == 2

    assert from(idea_idea_label in IdeaIdeaLabel,
             where:
               idea_idea_label.idea_label_id ==
                 ^brainstorming_label_1.id and
                 idea_idea_label.idea_id == ^idea_1.id
           )
           |> Repo.one!()

    assert from(idea_idea_label in IdeaIdeaLabel,
             where:
               idea_idea_label.idea_label_id ==
                 ^brainstorming_label_2.id and
                 idea_idea_label.idea_id == ^idea_2.id
           )
           |> Repo.one!()
  end

  test "fails gracefully", %{
    brainstorming: _brainstorming,
    brainstorming_label_1: brainstorming_label_1,
    idea_1: idea_1,
    brainstorming_label_2: _brainstorming_label_2,
    idea_2: _idea_2
  } do
    Factory.insert!(:idea_idea_label, idea: idea_1, idea_label: brainstorming_label_1)

    assert_raise Postgrex.Error, fn -> MigrateIdeaLabelsToIdeaIdeaLabels.run() end
  end
end
