defmodule Mindwendel.AccountsTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Accounts
  alias Mindwendel.Accounts.BrainstormingModeratingUser
  alias Mindwendel.Accounts.BrainstormingUser
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Factory

  import ExUnit.CaptureLog

  setup do
    user = Factory.insert!(:user)
    brainstorming = Factory.insert!(:brainstorming)

    %{
      brainstorming: brainstorming,
      user: user
    }
  end

  describe "#add_moderating_user" do
    test "adds a moderating user to the brainstorming", %{
      brainstorming: brainstorming,
      user: %User{id: user_id} = user
    } do
      Accounts.add_moderating_user(brainstorming, user)

      assert 1 = Repo.one(from(bmu in BrainstormingModeratingUser, select: count(bmu.user_id)))
      assert brainstorming_moderatoring_user = Repo.one(BrainstormingModeratingUser)
      assert brainstorming_moderatoring_user.user_id == user.id
      assert brainstorming_moderatoring_user.brainstorming_id == brainstorming.id

      {:ok, brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
      assert [%User{id: ^user_id}] = brainstorming.moderating_users
    end

    test "responds with an error when brainstorming already contains the moderating user", %{
      brainstorming: brainstorming,
      user: user
    } do
      Accounts.add_moderating_user(brainstorming, user)

      assert {:error,
              %Ecto.Changeset{
                valid?: false,
                errors: [
                  brainstorming_id: {_, [{:constraint, :unique}, _]}
                ]
              }} = Accounts.add_moderating_user(brainstorming, user)
    end
  end

  describe "get_or_create_user" do
    test "get existing user", %{user: existing_user} do
      user = Accounts.get_or_create_user(existing_user.id)

      assert user.id == existing_user.id
      assert Repo.aggregate(User, :count) == 1
    end

    test "create new (non-existing) user" do
      user_id = Ecto.UUID.generate()
      user = Accounts.get_or_create_user(user_id)

      assert user.id == user_id
      assert Repo.aggregate(User, :count) == 2
    end
  end

  describe "get_user" do
    test "returns user when it exists", %{user: existing_user} do
      assert existing_user |> Repo.preload([:brainstormings, :moderated_brainstormings]) ==
               Accounts.get_user(existing_user.id)
    end

    test "returns nil when nil is given" do
      assert is_nil(Accounts.get_user(nil))
    end
  end

  describe "update_user" do
    test "updates the username of a user", %{user: existing_user} do
      {:ok, updated_user} = Accounts.update_user(existing_user, %{username: "test"})
      assert updated_user.username == "test"
    end
  end

  describe "delete_inactive_users" do
    setup do
      old_brainstorming =
        Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-01 10:00:00])
        |> Repo.preload(:users)

      old_user = Factory.insert!(:user, updated_at: ~N[2021-01-01 10:00:00])

      updated_old_brainstorming =
        Accounts.merge_brainstorming_user(old_brainstorming, old_user.id)

      %{
        old_user: old_user,
        old_brainstorming: updated_old_brainstorming
      }
    end

    test "removes the old user", %{old_user: old_user} do
      Accounts.delete_inactive_users()

      refute Repo.exists?(from u in User, where: u.id == ^old_user.id)
    end

    test "does not remove new users", %{user: user} do
      assert Repo.exists?(from u in User, where: u.id == ^user.id)
    end

    test "removes the old brainstorming users", %{old_user: old_user} do
      Accounts.delete_inactive_users()
      refute Repo.exists?(from b_user in BrainstormingUser, where: b_user.user_id == ^old_user.id)
    end

    test "does not delete the brainstorming", %{old_brainstorming: old_brainstorming} do
      Accounts.delete_inactive_users()
      assert Repo.exists?(from b in Brainstorming, where: b.id == ^old_brainstorming.id)
    end

    test "does not delete the user is still attached to ideas", %{
      old_user: old_user,
      old_brainstorming: old_brainstorming
    } do
      Factory.insert!(:idea, brainstorming: old_brainstorming, user: old_user)

      # Ensure the database is not enforcing this via foreign keys but that the
      # application handles the constraint.
      log = capture_log(fn -> Accounts.delete_inactive_users() end)

      assert Repo.exists?(from u in User, where: u.id == ^old_user.id)

      # The code only logs normal messages on `info` level which tests don't print
      # (only warning and above). Since tests run async we can't assert an empty
      # log, but we can assert we do not hit the messages we expect to see.
      refute log =~ ~r/error.*delete.*inactive.*user.*#{old_user.id}/i
    end

    test "does not delete the user a user is a creating user of a brainstorming", %{
      old_user: old_user
    } do
      Factory.insert!(:brainstorming,
        creating_user: old_user,
        inserted_at: ~N[2021-01-01 10:00:00]
      )

      # Ensure the database is not enforcing this via foreign keys but that the
      # application handles the constraint.
      log = capture_log(fn -> Accounts.delete_inactive_users() end)

      assert Repo.exists?(from u in User, where: u.id == ^old_user.id)
      refute log =~ ~r/error.*delete.*inactive.*user.*#{old_user.id}/i
    end

    test "does not delete the user a user is a moderating user of a brainstorming", %{
      old_user: old_user
    } do
      Factory.insert!(:brainstorming,
        moderating_users: [old_user],
        inserted_at: ~N[2021-01-01 10:00:00]
      )

      # Ensure the database is not enforcing this via foreign keys but that the
      # application handles the constraint.
      log = capture_log(fn -> Accounts.delete_inactive_users() end)

      assert Repo.exists?(from u in User, where: u.id == ^old_user.id)
      # We do not expect actual logs, but other async tests may emit logs at the
      # same time. Make sure no delete logs around the user are emitted.
      refute log =~ ~r/error.*delete.*inactive.*user.*#{old_user.id}/i
    end
  end
end
