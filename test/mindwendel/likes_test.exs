defmodule Mindwendel.LikesTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Factory
  alias Mindwendel.Likes

  setup do
    user = Factory.insert!(:user)
    brainstorming = Factory.insert!(:brainstorming, users: [user])

    %{
      brainstorming: brainstorming,
      idea:
        Factory.insert!(:idea, brainstorming: brainstorming, inserted_at: ~N[2021-01-01 15:04:30]),
      user: user,
      like: Factory.insert!(:like, :with_idea_and_user)
    }
  end

  describe "exists_user_in_likes?" do
    test "returns true if like is given", %{idea: idea, user: user} do
      Factory.insert!(:like, %{idea_id: idea.id, user_id: user.id})
      likes = Repo.all(from like in Like, where: like.idea_id == ^idea.id)
      assert Likes.exists_user_in_likes?(likes, user.id) == true
    end

    test "returns false if like is not given", %{idea: idea, user: user} do
      likes = Repo.all(from like in Like, where: like.idea_id == ^idea.id)
      assert Likes.exists_user_in_likes?(likes, user.id) == false
    end
  end

  describe "increment_likes_for_idea" do
    test "adds a like", %{idea: idea, user: user} do
      Likes.add_like(idea.id, user.id)
      count = idea |> assoc(:likes) |> Repo.aggregate(:count, :id)
      assert count == 1
    end

    test "can't add a second like", %{idea: idea, user: user} do
      Factory.insert!(:like, %{idea_id: idea.id, user_id: user.id})
      Likes.add_like(idea.id, user.id)
      count = idea |> assoc(:likes) |> Repo.aggregate(:count, :id)
      assert count == 1
    end
  end

  describe "delete_likes" do
    @tag individual_test: "true"
    test "deletes a like", %{like: like} do
      count = like.idea |> assoc(:likes) |> Repo.aggregate(:count, :id)
      assert count == 1

      # delete like:
      Likes.delete_like(like.idea.id, like.user.id)

      count = like.idea |> assoc(:likes) |> Repo.aggregate(:count, :id)
      assert count == 0
    end
  end

  describe "count_likes_for_idea" do
    test "count likes", %{like: like} do
      assert Ecto.assoc(like, :idea)
             |> Repo.one()
             |> Likes.count_likes_for_idea() == 1
    end
  end
end
