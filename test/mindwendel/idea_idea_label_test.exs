defmodule Mindwendel.IdeaIdeaLabelTest do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory

  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Repo

  describe "#valid?" do
    setup do
      idea = Factory.build(:idea)
      idea_label = idea.brainstorming.labels |> Enum.at(0)

      idea_idea_label = Factory.insert!(:idea_idea_label, idea: idea, idea_label: idea_label)

      %{
        idea: idea,
        idea_label: idea_label,
        idea_idea_label: idea_idea_label
      }
    end

    test "valid with idea and idea_label", %{idea: idea} do
      idea_label = idea.brainstorming.labels |> Enum.at(0)

      idea_idea_label_changeset =
        %IdeaIdeaLabel{idea: idea, idea_label: idea_label} |> IdeaIdeaLabel.changeset()

      assert idea_idea_label_changeset.valid?
    end

    test "require idea", %{idea: idea, idea_label: idea_label} do
      idea_idea_label = %IdeaIdeaLabel{idea: idea, idea_label: idea_label}

      assert_raise RuntimeError, ~r/:idea/, fn ->
        IdeaIdeaLabel.changeset(idea_idea_label, %{idea: nil})
      end
    end

    test "require idea_label", %{idea: idea, idea_label: idea_label} do
      idea_idea_label = %IdeaIdeaLabel{idea: idea, idea_label: idea_label}

      assert_raise RuntimeError, ~r/:idea_label/, fn ->
        IdeaIdeaLabel.changeset(idea_idea_label, %{idea_label: nil})
      end
    end

    test "require idea_labels", %{idea: idea, idea_label: idea_label} do
      idea_idea_label = %IdeaIdeaLabel{idea: idea, idea_label: idea_label}

      assert_raise RuntimeError, fn ->
        IdeaIdeaLabel.changeset(idea_idea_label, %{idea: nil, idea_label: nil})
      end
    end

    test "require to be uniq", %{
      idea: idea,
      idea_label: idea_label
    } do
      Repo.aggregate(IdeaIdeaLabel, :count, :idea_id)

      idea_idea_label = %IdeaIdeaLabel{idea: idea, idea_label: idea_label}
      IdeaIdeaLabel.changeset(idea_idea_label) |> Repo.insert!()

      Repo.aggregate(IdeaIdeaLabel, :count, :idea_id)
    end
  end
end
