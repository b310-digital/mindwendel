defmodule Mindwendel.Repo.DataMigrations.MigrateIdealLabelsTest do
  Code.require_file("./priv/repo/data_migrations/migrate_idea_labels.exs")

  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Repo.DataMigrations.MigrateIdealLabels

  setup do
    %{brainstorming: Factory.insert!(:brainstorming, %{labels: []})}
  end

  describe "#prepare_labels_for_brainstormings/0" do
    test "adds up to five idea labels for each brainstorming", %{
      brainstorming: existing_brainstorming
    } do
      existing_brainstorming = Repo.preload(existing_brainstorming, :labels)
      assert Enum.empty?(existing_brainstorming.labels)

      MigrateIdealLabels.run()

      updated_brainstorming = Repo.reload(existing_brainstorming) |> Repo.preload(:labels)

      assert Enum.count(updated_brainstorming.labels) == 5
    end

    test "considers existing idea_labels and adds up to five idea labels for each brainstorming" do
      idea_label_1 = %IdeaLabel{name: "idea_label_1", position_order: 7}
      idea_label_2 = %IdeaLabel{name: "idea_label_2", position_order: 8}

      brainstroming_with_two_labels =
        %Brainstorming{name: "How to brainstorm ideas?", labels: [idea_label_1, idea_label_2]}
        |> Repo.insert!()

      assert Enum.count(brainstroming_with_two_labels.labels) == 2

      MigrateIdealLabels.run()

      updated_brainstorming = Repo.reload(brainstroming_with_two_labels) |> Repo.preload(:labels)
      assert Enum.count(updated_brainstorming.labels) == 5

      assert Enum.map(updated_brainstorming.labels, &Map.take(&1, [:name, :position_order])) == [
               %{name: idea_label_1.name, position_order: 7},
               %{name: idea_label_2.name, position_order: 8},
               %{name: "cyan", position_order: 0},
               %{name: "gray dark", position_order: 1},
               %{name: "green", position_order: 2}
             ]
    end

    test "does not add additional idea labels when running multiple times", %{
      brainstorming: existing_brainstorming
    } do
      # Running twice
      MigrateIdealLabels.run()
      MigrateIdealLabels.run()

      updated_brainstorming = Repo.reload(existing_brainstorming) |> Repo.preload(:labels)
      assert Enum.count(updated_brainstorming.labels) == 5
    end
  end

  describe "#migrate_labels_from_ideas/0" do
    test "connects idea to its idea label", %{
      brainstorming: existing_brainstorming
    } do
      idea =
        Factory.build(:idea, deprecated_label: :label_1, brainstorming: existing_brainstorming)
        |> Repo.insert!()

      MigrateIdealLabels.run()

      updated_idea = Repo.reload(idea) |> Repo.preload([:label, brainstorming: [:labels]])

      assert updated_idea.label.name == "cyan"

      assert Enum.map(updated_idea.brainstorming.labels, & &1.id)
             |> Enum.member?(updated_idea.label.id)
    end
  end

  test "does not override existing label with deprecated_label" do
    idea_label = Factory.insert!(:idea_label, name: "Topic A")
    brainstorming = Factory.insert!(:brainstorming, labels: [idea_label])

    idea =
      Factory.insert!(:idea,
        deprecated_label: :label_1,
        label: idea_label,
        brainstorming: brainstorming
      )

    MigrateIdealLabels.run()

    updated_idea = Repo.reload(idea) |> Repo.preload([:label, brainstorming: [:labels]])
    assert updated_idea.label.id == idea_label.id
    assert updated_idea.label.name == idea_label.name

    updated_brainstorming = Repo.reload(brainstorming) |> Repo.preload([:labels])
    assert Enum.map(updated_brainstorming.labels, & &1.id) |> Enum.member?(idea_label.id)
  end

  test "migrate predefined values of field deprecated_label", %{
    brainstorming: existing_brainstorming
  } do
    for {k, v} <- MigrateIdealLabels.deprecated_label_to_idea_label_name_mapping() do
      idea = Factory.insert!(:idea, deprecated_label: k, brainstorming: existing_brainstorming)

      MigrateIdealLabels.run()

      updated_idea = Repo.reload(idea) |> Repo.preload([:label, brainstorming: [:labels]])

      assert updated_idea.label.name == v
    end
  end
end
