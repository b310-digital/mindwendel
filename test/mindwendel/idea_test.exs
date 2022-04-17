defmodule Mindwendel.IdeaTest do
  use Mindwendel.DataCase
  alias Mindwendel.Factory

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Idea

  describe("Factory.build(:idea)") do
    setup do
      brainstorming = Factory.insert!(:brainstorming)

      idea =
        Factory.build(:idea, brainstorming_id: brainstorming.id, brainstorming: brainstorming)

      %{
        brainstorming: brainstorming,
        idea: idea
      }
    end

    test "builds object", %{idea: idea} do
      assert idea
    end

    test "builds valid object", %{idea: idea} do
      idea_changeset = Idea.changeset(idea)
      assert idea_changeset.valid?
    end
  end

  describe("Factory.insert!(:idea)") do
    setup do
      %{idea: Factory.insert!(:idea)}
    end

    test "saves without problem", %{idea: idea} do
      assert idea
    end

    test "saves object in database" do
      assert Brainstormings.list_ideas() |> Enum.count() == 1
    end
  end

  describe "#valid?" do
    setup do
      brainstorming = Factory.insert!(:brainstorming)

      idea =
        Factory.build(:idea, brainstorming_id: brainstorming.id, brainstorming: brainstorming)

      %{
        brainstorming: brainstorming,
        idea: idea
      }
    end

    # test "require brainstorming", %{idea: idea} do
    #   assert_raise RuntimeError, ~r/:brainstorming/, fn ->
    #     Idea.changeset(idea, %{brainstorming: nil})
    #   end
    # end

    test "require present body", %{idea: idea} do
      refute Idea.changeset(idea, %{body: nil}).valid?
      refute Idea.changeset(idea, %{body: ""}).valid?
      assert Idea.changeset(idea, %{body: "More than two characters"}).valid?
    end
  end

  @tag :skip
  describe "#update_idea" do
    setup do
      %{idea: Factory.insert!(:idea)}
    end

    test "update idea_labels", %{idea: idea} do
      IO.inspect(idea)
      Brainstormings.update_idea(idea, %{idea_labels: []})

      assert Enum.empty?(idea.idea_labels)
    end

    @tag :skip
    test "only accepts idea_labels of associated brainstorming"

    @tag :skip
    test "does not save duplicate idea_labels "
  end
end
