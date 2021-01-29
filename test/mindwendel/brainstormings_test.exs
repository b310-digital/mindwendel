defmodule Mindwendel.BrainstormingsTest do
  use Mindwendel.DataCase
  alias Mindwendel.Factory
  alias Mindwendel.Brainstormings

  setup do
    %{
      brainstorming: Factory.insert!(:brainstorming),
      idea: Factory.insert!(:idea),
      user: Factory.insert!(:user),
      like: Factory.insert!(:like, :with_idea_and_user)
    }
  end

  describe "change brainstorming" do
    test "shortens the brainstorming name if it is too long", %{brainstorming: brainstorming} do
      result =
        Brainstormings.change_brainstorming(brainstorming, %{
          name: """
          Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. \
          """
        })

      assert result.changes.name == """
             Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores e\
             """
    end
  end

  describe "list_ideas_for_brainstorming" do
    test "orders by like count", %{brainstorming: brainstorming, user: user} do
      first_idea = Factory.insert!(:idea, brainstorming_id: brainstorming.id)
      third_idea = Factory.insert!(:idea, brainstorming_id: brainstorming.id)
      second_idea = Factory.insert!(:idea, brainstorming_id: brainstorming.id)

      another_user = Factory.insert!(:user)

      Brainstormings.add_like(first_idea.id, user.id)
      Brainstormings.add_like(first_idea.id, another_user.id)
      Brainstormings.add_like(second_idea.id, user.id)

      ids =
        Enum.map(Brainstormings.list_ideas_for_brainstorming(brainstorming.id), fn x -> x.id end)

      assert ids == [first_idea.id, second_idea.id, third_idea.id]
    end

    test "orders by date if like count is equal", %{brainstorming: brainstorming, user: user} do
      older_idea =
        Factory.insert!(:idea,
          brainstorming_id: brainstorming.id,
          inserted_at: ~N[2021-01-15 15:04:30]
        )

      younger_idea =
        Factory.insert!(:idea,
          brainstorming_id: brainstorming.id,
          inserted_at: ~N[2021-01-15 15:05:30]
        )

      Brainstormings.add_like(older_idea.id, user.id)
      Brainstormings.add_like(younger_idea.id, user.id)

      ids =
        Enum.map(Brainstormings.list_ideas_for_brainstorming(brainstorming.id), fn x -> x.id end)

      assert ids == [younger_idea.id, older_idea.id]
    end
  end

  describe "exists_like_for_idea?" do
    test "returns true if like is given", %{idea: idea, user: user} do
      Factory.insert!(:like, %{idea_id: idea.id, user_id: user.id})
      assert Brainstormings.exists_like_for_idea?(idea.id, user.id) == true
    end

    test "returns false if like is not given", %{idea: idea, user: user} do
      assert Brainstormings.exists_like_for_idea?(idea.id, user.id) == false
    end
  end

  describe "increment_likes_for_idea" do
    test "adds a like", %{idea: idea, user: user} do
      Brainstormings.add_like(idea.id, user.id)
      count = idea |> assoc(:likes) |> Repo.aggregate(:count, :id)
      assert count == 1
    end

    test "can't add a second like", %{idea: idea, user: user} do
      Factory.insert!(:like, %{idea_id: idea.id, user_id: user.id})
      Brainstormings.add_like(idea.id, user.id)
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
      Brainstormings.delete_like(like.idea.id, like.user.id)

      count = like.idea |> assoc(:likes) |> Repo.aggregate(:count, :id)
      assert count == 0
    end
  end

  describe "count_likes_for_idea" do
    test "count likes", %{like: like} do
      assert Ecto.assoc(like, :idea)
             |> Repo.one()
             |> Brainstormings.count_likes_for_idea() == 1
    end
  end
end
