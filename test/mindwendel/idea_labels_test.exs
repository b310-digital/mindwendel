defmodule Mindwendel.IdeaLabelsTest do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory

  alias Mindwendel.Ideas
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.IdeaIdeaLabel

  setup do
    brainstorming = Factory.insert!(:brainstorming, %{labels: [Factory.build(:idea_label)]})
    [idea_label] = brainstorming.labels
    lane = Enum.at(brainstorming.lanes, 0)
    idea = Factory.insert!(:idea, %{brainstorming: brainstorming, lane: lane})

    %{idea_label: idea_label, brainstorming: brainstorming, idea: idea}
  end

  describe "#add_idea_label_to_idea" do
    test "adds IdeaLabel to Idea", %{idea_label: idea_label, idea: idea} do
      {:ok, _idea_idea_label} = IdeaLabels.add_idea_label_to_idea(idea, idea_label.id)

      assert [idea_label] == labels_of(idea)
      assert Repo.count(IdeaIdeaLabel) == 1
    end

    test "creates one IdeaIdeaLabel", %{idea_label: idea_label, idea: idea} do
      {:ok, _idea_idea_label} = IdeaLabels.add_idea_label_to_idea(idea, idea_label.id)

      assert Repo.count(IdeaIdeaLabel) == 1

      idea_idea_label = Repo.one(IdeaIdeaLabel)
      assert idea_idea_label.idea_label_id == idea_label.id
      assert idea_idea_label.idea_id == idea.id
    end

    test "does not create additional IdeaLabel", %{idea_label: idea_label, idea: idea} do
      assert Repo.count(IdeaLabel) == 1

      {:ok, _idea_idea_label} = IdeaLabels.add_idea_label_to_idea(idea, idea_label.id)

      assert Repo.count(IdeaLabel) == 1
      assert Repo.one(IdeaLabel) == idea_label
    end

    @tag :skip
    test "does not add the same IdeaLabel twice to Idea", %{idea_label: idea_label, idea: idea} do
      # Calling this method twice does not fail and does not create duplicates
      {:ok, idea_idea_label_after_method_call_1} =
        IdeaLabels.add_idea_label_to_idea(idea, idea_label.id)

      {:ok, idea_idea_label_after_method_call_2} =
        IdeaLabels.add_idea_label_to_idea(idea, idea_label.id)

      # There should still be only one IdeaIdeaLabel
      assert Repo.count(IdeaIdeaLabel) == 1

      assert Repo.count(IdeaLabel) == 1

      assert idea_idea_label_after_method_call_1 == idea_idea_label_after_method_call_2
    end

    @tag :skip
    test "does not add an IdeaLabel from another brainstorming", %{idea: idea} do
      another_brainstorming = Factory.insert!(:brainstorming, %{labels: []})

      idea_label_from_another_brainstorming =
        Factory.build(:idea_label, %{
          name: "another idea_label",
          brainstorming: another_brainstorming
        })

      {:error, _changeset} =
        IdeaLabels.add_idea_label_to_idea(idea, idea_label_from_another_brainstorming.id)
    end

    @tag :skip
    test "update idea_labels", %{idea: idea} do
      idea = Repo.preload(idea, :idea_labels)
      _idea_label = idea.brainstorming.labels |> Enum.at(0)
      Ideas.update_idea(idea, %{idea_labels: []})

      assert Enum.empty?(idea.idea_labels)
    end

    @tag :skip
    test "only accepts idea_labels of associated brainstorming"

    @tag :skip
    test "does not save duplicate idea_labels"

    @tag :skip
    test "does not create idea_labels without brainstorming", %{idea: idea} do
      assert Repo.count(IdeaIdeaLabel) == 0
      idea = Repo.preload(idea, [:idea_labels, :idea_idea_labels])
      idea_label = idea.brainstorming.labels |> Enum.at(0)

      IdeaLabels.add_idea_label_to_idea(idea, idea_label.id)

      assert Repo.count(IdeaIdeaLabel) == 1
      assert Repo.one(IdeaIdeaLabel).idea_id == idea.id
      assert Repo.one(IdeaIdeaLabel).idea_label_id == idea_label.id
      assert Repo.count(IdeaLabel) == 5

      assert Enum.empty?(
               Repo.all(
                 from idea_label in IdeaLabel,
                   where: is_nil(idea_label.brainstorming_id)
               )
             )
    end
  end

  describe "#delete_idea_label_from_idea" do
    setup %{idea_label: idea_label, idea: idea} do
      {:ok, _idea_idea_label} = IdeaLabels.add_idea_label_to_idea(idea, idea_label.id)
      idea = idea |> Repo.reload!() |> Repo.preload(:idea_labels)
      assert Repo.count(IdeaIdeaLabel) == 1
      %{idea: idea}
    end

    test "removes successfully IdeaLabel from Idea", %{idea_label: idea_label, idea: idea} do
      IdeaLabels.remove_idea_label_from_idea(idea, idea_label.id)
      assert Enum.empty?(Repo.all(IdeaIdeaLabel))
    end

    test "does not break when removing IdeaLabel that is not connected to Idea yet", %{
      idea_label: idea_label,
      idea: idea
    } do
      # Calling this method twice does not fail
      IdeaLabels.remove_idea_label_from_idea(idea, idea_label.id)
      IdeaLabels.remove_idea_label_from_idea(idea, idea_label.id)

      assert Enum.empty?(Repo.all(IdeaIdeaLabel))
    end
  end

  defp labels_of(idea_record) do
    Repo.all(
      from idea_label in IdeaLabel,
        join: idea in assoc(idea_label, :ideas),
        where: idea.id == ^idea_record.id
    )
  end
end
