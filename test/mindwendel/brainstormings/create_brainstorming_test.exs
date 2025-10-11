defmodule Mindwendel.Brainstormings.CreateBrainstormingTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Accounts.BrainstormingModeratingUser
  alias Mindwendel.Accounts.BrainstormingUser
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Factory

  describe "#create_brainstorming" do
    @brainstorming_attrs %{name: "brainstorming_name"}

    setup do
      user = Factory.insert!(:user)

      %{user: user}
    end

    test "creates five default idea_labels when no idea label given", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, @brainstorming_attrs)

      assert [
               %IdeaLabel{},
               %IdeaLabel{},
               %IdeaLabel{},
               %IdeaLabel{},
               %IdeaLabel{}
             ] = brainstorming.labels

      assert 5 = Repo.one(from q in IdeaLabel, select: count(q.id))
    end

    test "creates brainstorming referencing creating_user", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, @brainstorming_attrs)

      assert brainstorming.creating_user_id == user.id
    end

    test "creates brainstorming referencing moderatoring_users", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, @brainstorming_attrs)

      assert brainstorming.moderating_users == [user]

      brainstorming_moderating_user = Repo.one(BrainstormingModeratingUser)
      assert brainstorming_moderating_user.user_id == user.id
      assert brainstorming_moderating_user.brainstorming_id == brainstorming.id
    end

    test "creates brainstorming with correct associations from user model", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, @brainstorming_attrs)

      user =
        Repo.reload(user)
        |> Repo.preload([
          :brainstormings,
          :created_brainstormings,
          :moderated_brainstormings
        ])

      brainstorming_id = brainstorming.id
      assert [%Brainstorming{id: ^brainstorming_id}] = user.brainstormings
      assert [%Brainstorming{id: ^brainstorming_id}] = user.created_brainstormings
      assert [%Brainstorming{id: ^brainstorming_id}] = user.moderated_brainstormings
      assert user.brainstormings == user.created_brainstormings
      assert user.moderated_brainstormings == user.created_brainstormings
    end

    test "does not create additional user", %{user: user} do
      {:ok, _brainstorming} = Brainstormings.create_brainstorming(user, @brainstorming_attrs)

      assert Repo.one(User) == user
    end

    test "creates brainstorming referencing users", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, @brainstorming_attrs)

      assert brainstorming.users == [user]

      brainstorming_user = Repo.one(BrainstormingUser)
      assert brainstorming_user.user_id == user.id
      assert brainstorming_user.brainstorming_id == brainstorming.id
    end

    test "creates brainstorming referencing the same user as user, creating_user and moderating_user",
         %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, @brainstorming_attrs)

      brainstorming =
        Repo.reload(brainstorming)
        |> Repo.preload([:users, :creating_user, :moderating_users])

      assert brainstorming.users == brainstorming.moderating_users
      assert brainstorming.moderating_users |> List.first() == brainstorming.creating_user
    end
  end
end
