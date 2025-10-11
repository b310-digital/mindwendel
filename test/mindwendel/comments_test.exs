defmodule Mindwendel.CommentsTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Comments
  alias Mindwendel.Factory

  setup do
    idea = Factory.insert!(:idea)

    %{
      idea: idea
    }
  end

  describe "create_comment" do
    test "increments comment count on idea", %{idea: idea} do
      {:ok, _comment} = Comments.create_comment(%{body: "test", idea_id: idea.id})
      assert Repo.get_by!(Idea, id: idea.id).comments_count == 1
    end
  end

  describe "delete_comment" do
    test "decrements comment count on idea", %{idea: idea} do
      {:ok, comment} = Comments.create_comment(%{body: "test", idea_id: idea.id})
      {:ok, _comment} = Comments.delete_comment(comment)
      assert Repo.get_by!(Idea, id: idea.id).comments_count == 0
    end
  end
end
