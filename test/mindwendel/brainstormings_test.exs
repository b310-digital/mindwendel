defmodule Mindwendel.BrainstormingsTest do
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  use Mindwendel.DataCase
  alias Mindwendel.Brainstormings.BrainstormingModeratingUser
  alias Mindwendel.Factory

  alias Mindwendel.Brainstormings
  alias Mindwendel.IdeaLabels
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
      like: Factory.insert!(:like, :with_idea_and_user),
      lane: Enum.at(brainstorming.lanes, 0)
    }
  end

  describe "create_brainstorming" do
    test "creates a lane", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, %{name: "test"})
      assert length(brainstorming.lanes) == 1
    end

    test "creates labels", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, %{name: "test"})
      assert length(brainstorming.labels) == 5
    end
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

  describe "delete_old_brainstormings" do
    test "removes the brainstorming" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(b in Brainstorming, where: b.id == ^old_brainstorming.id))
    end

    test "removes a recently inactive brainstorming " do
      days = 30

      inactive_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at:
            DateTime.utc_now() |> Timex.shift(days: -days - 1) |> DateTime.truncate(:second)
        )

      Brainstormings.delete_old_brainstormings(days)

      refute Repo.exists?(from(b in Brainstorming, where: b.id == ^inactive_brainstorming.id))
    end

    test "does not remove a recently accessed brainstorming " do
      days = 30

      active_brainstorming =
        Factory.insert!(
          :brainstorming,
          last_accessed_at:
            DateTime.utc_now() |> Timex.shift(days: -days + 1) |> DateTime.truncate(:second)
        )

      Brainstormings.delete_old_brainstormings(days)

      assert Repo.exists?(from(b in Brainstorming, where: b.id == ^active_brainstorming.id))
    end

    test "removes the old brainstormings ideas" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(i in Idea, where: i.id == ^old_idea.id))
    end

    test "removes the old brainstormings likes" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

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
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

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
        Factory.insert!(:brainstorming,
          users: [user],
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      Brainstormings.delete_old_brainstormings()

      refute Enum.member?(Brainstormings.list_brainstormings_for(user.id), old_brainstorming.id)
    end

    test "does not remove the user", %{user: user} do
      inactive_brainstorming =
        Factory.insert!(:brainstorming,
          users: [user],
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(b in Brainstorming, where: b.id == ^inactive_brainstorming.id))
      assert Repo.exists?(from(u in User, where: u.id == ^user.id))
    end

    test "keeps the new brainstorming", %{brainstorming: brainstorming} do
      Brainstormings.delete_old_brainstormings()

      assert Repo.exists?(from(b in Brainstorming, where: b.id == ^brainstorming.id))
    end
  end

  describe "empty/1 brainstormings" do
    test "empty/1 removes all ideas from a brainstorming", %{brainstorming: brainstorming} do
      brainstorming = brainstorming |> Repo.preload([:ideas])
      assert Enum.count(brainstorming.ideas) == 1
      Brainstormings.empty(brainstorming)
      # reload brainstorming:
      brainstorming = Brainstormings.get_brainstorming!(brainstorming.id)
      brainstorming = brainstorming |> Repo.preload([:ideas])
      assert Enum.empty?(brainstorming.lanes)
    end

    test "empty/1 also clears likes and labels from ideas", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30],
          lane: lane
        )

      like = Factory.insert!(:like, idea: idea)

      {:ok, idea} =
        IdeaLabels.add_idea_label_to_idea(idea, Enum.at(brainstorming.labels, 0))

      idea = idea |> Repo.preload([:idea_labels])

      Brainstormings.empty(brainstorming)
      # reload brainstorming:
      brainstorming = Brainstormings.get_brainstorming!(brainstorming.id)

      assert Enum.empty?(brainstorming.lanes)
      assert Repo.get_by(Idea, id: idea.id) == nil
      assert Repo.get_by(IdeaIdeaLabel, idea_id: idea.id) == nil
      assert Repo.get_by(Like, id: like.id) == nil
    end

    test "empty/1 does not removes all ideas from other brainstormings", %{
      brainstorming: brainstorming
    } do
      other_brainstorming = Factory.insert!(:brainstorming)
      other_lane = Enum.at(brainstorming.lanes, 0)

      Factory.insert!(:idea,
        brainstorming: other_brainstorming,
        lane: other_lane
      )

      other_brainstorming = other_brainstorming |> Repo.preload([:ideas])

      assert Enum.count(other_brainstorming.ideas) == 1
      Brainstormings.empty(brainstorming)
      # reload brainstorming:
      brainstorming = Brainstormings.get_brainstorming!(brainstorming.id)
      brainstorming = brainstorming |> Repo.preload([:ideas])
      other_brainstorming = other_brainstorming |> Repo.preload([:ideas])
      assert Enum.empty?(brainstorming.lanes)
      assert Enum.count(other_brainstorming.lanes) == 1
    end
  end
end
