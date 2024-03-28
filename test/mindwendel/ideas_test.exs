defmodule Mindwendel.IdeasTest do
  use Mindwendel.DataCase
  alias Mindwendel.Factory

  alias Mindwendel.Likes
  alias Mindwendel.Ideas

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

  describe "list_ideas_for_brainstorming" do
    test "orders by like count", %{brainstorming: brainstorming, user: user, idea: idea} do
      first_idea = Factory.insert!(:idea, brainstorming: brainstorming)
      third_idea = Factory.insert!(:idea, brainstorming: brainstorming)
      second_idea = Factory.insert!(:idea, brainstorming: brainstorming)

      another_user = Factory.insert!(:user)

      Likes.add_like(first_idea.id, user.id)
      Likes.add_like(first_idea.id, another_user.id)
      Likes.add_like(second_idea.id, user.id)

      ids =
        Enum.map(Ideas.list_ideas_for_brainstorming(brainstorming.id), fn x -> x.id end)

      assert ids == [first_idea.id, second_idea.id, third_idea.id, idea.id]
    end

    test "orders by date if like count is equal", %{
      brainstorming: brainstorming,
      user: user,
      idea: idea
    } do
      older_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          inserted_at: ~N[2021-01-15 15:04:30]
        )

      younger_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          inserted_at: ~N[2021-01-15 15:05:30]
        )

      Likes.add_like(older_idea.id, user.id)
      Likes.add_like(younger_idea.id, user.id)

      ids =
        Enum.map(Ideas.list_ideas_for_brainstorming(brainstorming.id), fn x -> x.id end)

      assert ids == [younger_idea.id, older_idea.id, idea.id]
    end
  end

  describe "sort_ideas_by_labels" do
    test "sorts without ideas" do
      brainstorming_without_ideas = Factory.insert!(:brainstorming)

      ideas_sorted_by_labels = Ideas.sort_ideas_by_labels(brainstorming_without_ideas.id)

      assert ideas_sorted_by_labels |> Enum.empty?()
      assert ideas_sorted_by_labels == []
    end

    test "sorts unlabelled ideas based on inserted_at", %{
      brainstorming: brainstorming,
      idea: idea_old
    } do
      idea_young = Factory.insert!(:idea, %{brainstorming: brainstorming})

      ideas_sorted_by_labels = Ideas.sort_ideas_by_labels(brainstorming.id)

      assert ideas_sorted_by_labels |> Enum.map(& &1.id) == [idea_young.id, idea_old.id]
    end

    test "sorts labelled ideas based on label position order and inserted_at", %{
      brainstorming: brainstorming,
      idea: idea_without_label
    } do
      brainstorming = brainstorming |> Repo.preload([:labels])

      idea_with_1st_label_older =
        Factory.insert!(:idea, %{
          brainstorming: brainstorming,
          label: Enum.at(brainstorming.labels, 0)
        })

      idea_with_second_label =
        Factory.insert!(:idea, %{
          brainstorming: brainstorming,
          label: Enum.at(brainstorming.labels, 1)
        })

      # Created 10 seconds later than idea_with_1st_label_older
      idea_with_1st_label_younger =
        Factory.insert!(:idea, %{
          brainstorming: brainstorming,
          inserted_at: NaiveDateTime.add(idea_with_1st_label_older.inserted_at, 10),
          label: Enum.at(brainstorming.labels, 0)
        })

      ideas_sorted_by_labels = Ideas.sort_ideas_by_labels(brainstorming.id)

      assert Enum.map(ideas_sorted_by_labels, & &1.id) == [
               idea_with_1st_label_younger.id,
               idea_with_1st_label_older.id,
               idea_with_second_label.id,
               idea_without_label.id
             ]
    end
  end
end
