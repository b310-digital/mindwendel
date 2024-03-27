defmodule Mindwendel.BrainstormingsTest do
  use Mindwendel.DataCase
  alias Mindwendel.Brainstormings.BrainstormingModeratingUser
  alias Mindwendel.Factory

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Attachments.Link
  alias Mindwendel.Accounts.User

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

  describe "list_brainstormings_for" do
    test "returns the 3 most recent brainstormings", %{brainstorming: brainstorming, user: user} do
      older_brainstorming =
        Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-10 15:04:30], users: [user])

      oldest_brainstorming =
        Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-05 15:04:30], users: [user])

      assert Brainstormings.list_brainstormings_for(user.id) |> Enum.map(fn b -> b.id end) == [
               brainstorming.id,
               older_brainstorming.id,
               oldest_brainstorming.id
             ]
    end
  end

  describe "#add_moderating_user" do
    test "adds a moderating user to the brainstorming", %{
      brainstorming: brainstorming,
      user: %User{id: user_id} = user
    } do
      Brainstormings.add_moderating_user(brainstorming, user)

      assert 1 = Repo.one(from(bmu in BrainstormingModeratingUser, select: count(bmu.user_id)))
      assert brainstorming_moderatoring_user = Repo.one(BrainstormingModeratingUser)
      assert brainstorming_moderatoring_user.user_id == user.id
      assert brainstorming_moderatoring_user.brainstorming_id == brainstorming.id

      brainstorming = Repo.preload(brainstorming, :moderating_users)
      assert [%User{id: ^user_id}] = brainstorming.moderating_users
    end

    test "responds with an error when brainstorming already contains the moderating user", %{
      brainstorming: brainstorming,
      user: user
    } do
      Brainstormings.add_moderating_user(brainstorming, user)

      assert {:error,
              %Ecto.Changeset{
                valid?: false,
                errors: [
                  brainstorming_id: {_, [{:constraint, :unique}, _]}
                ]
              }} = Brainstormings.add_moderating_user(brainstorming, user)
    end
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
    test "orders by like count", %{brainstorming: brainstorming, user: user, idea: idea} do
      first_idea = Factory.insert!(:idea, brainstorming: brainstorming)
      third_idea = Factory.insert!(:idea, brainstorming: brainstorming)
      second_idea = Factory.insert!(:idea, brainstorming: brainstorming)

      another_user = Factory.insert!(:user)

      Brainstormings.add_like(first_idea.id, user.id)
      Brainstormings.add_like(first_idea.id, another_user.id)
      Brainstormings.add_like(second_idea.id, user.id)

      ids =
        Enum.map(Brainstormings.list_ideas_for_brainstorming(brainstorming.id), fn x -> x.id end)

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

      Brainstormings.add_like(older_idea.id, user.id)
      Brainstormings.add_like(younger_idea.id, user.id)

      ids =
        Enum.map(Brainstormings.list_ideas_for_brainstorming(brainstorming.id), fn x -> x.id end)

      assert ids == [younger_idea.id, older_idea.id, idea.id]
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

  describe "sort_ideas_by_labels" do
    test "sorts without ideas" do
      brainstorming_without_ideas = Factory.insert!(:brainstorming)

      ideas_sorted_by_labels = Brainstormings.sort_ideas_by_labels(brainstorming_without_ideas.id)

      assert ideas_sorted_by_labels |> Enum.empty?()
      assert ideas_sorted_by_labels == []
    end

    test "sorts unlabelled ideas based on inserted_at", %{
      brainstorming: brainstorming,
      idea: idea_old
    } do
      idea_young = Factory.insert!(:idea, %{brainstorming: brainstorming})

      ideas_sorted_by_labels = Brainstormings.sort_ideas_by_labels(brainstorming.id)

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

      ideas_sorted_by_labels = Brainstormings.sort_ideas_by_labels(brainstorming.id)

      assert Enum.map(ideas_sorted_by_labels, & &1.id) == [
               idea_with_1st_label_younger.id,
               idea_with_1st_label_older.id,
               idea_with_second_label.id,
               idea_without_label.id
             ]
    end
  end

  describe "delete_old_brainstormings" do
    test "removes the brainstorming" do
      old_brainstorming = Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-01 10:00:00])
      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(b in Brainstorming, where: b.id == ^old_brainstorming.id))
    end

    test "removes the old brainstormings ideas" do
      old_brainstorming = Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-01 10:00:00])

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(i in Idea, where: i.id == ^old_idea.id))
    end

    test "removes the old brainstormings likes" do
      old_brainstorming = Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-01 10:00:00])

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      old_like = Factory.insert!(:like, idea: old_idea)
      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(l in Like, where: l.id == ^old_like.id))
    end

    test "removes the old brainstormings links" do
      old_brainstorming = Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-01 10:00:00])

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      old_link = Factory.insert!(:link, idea: old_idea)
      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(l in Link, where: l.id == ^old_link.id))
    end

    test "removes the old brainstormings users connection", %{user: user} do
      old_brainstorming =
        Factory.insert!(:brainstorming, users: [user], inserted_at: ~N[2021-01-01 10:00:00])

      Brainstormings.delete_old_brainstormings()

      refute Enum.member?(Brainstormings.list_brainstormings_for(user.id), old_brainstorming.id)
    end

    test "does not remove the user", %{user: user} do
      Factory.insert!(:brainstorming, users: [user], inserted_at: ~N[2021-01-01 10:00:00])
      Brainstormings.delete_old_brainstormings()

      assert Repo.exists?(from(u in User, where: u.id == ^user.id))
    end

    test "keeps the new brainstorming", %{brainstorming: brainstorming} do
      Brainstormings.delete_old_brainstormings()

      assert Repo.exists?(from(b in Brainstorming, where: b.id == ^brainstorming.id))
    end
  end
end
