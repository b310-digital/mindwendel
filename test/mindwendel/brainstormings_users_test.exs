defmodule Mindwendel.AccountsMergeBrainstormingUserTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Accounts
  alias Mindwendel.Accounts.BrainstormingUser
  alias Mindwendel.Accounts.User
  alias Mindwendel.Factory

  setup do
    %{user: Factory.insert!(:user)}
  end

  describe "merge_brainstorming_users" do
    setup do
      %{brainstorming: Factory.insert!(:brainstorming, :with_users) |> Repo.preload(:users)}
    end

    test "returns brainstorming with existing user added", %{
      brainstorming: brainstorming,
      user: existing_user
    } do
      refute existing_user.id in (brainstorming.users |> Enum.map(& &1.id))

      brainstorming = brainstorming |> Accounts.merge_brainstorming_user(existing_user.id)

      assert existing_user.id in (brainstorming.users |> Enum.map(& &1.id))
      assert Repo.aggregate(User, :count) == 2

      assert Repo.one(
               from bd in BrainstormingUser,
                 where: bd.brainstorming_id == ^brainstorming.id,
                 select: count(bd.id)
             ) == 2

      assert Repo.one(
               from bd in BrainstormingUser,
                 where: bd.user_id == ^existing_user.id,
                 select: count(bd.id)
             ) == 1
    end

    test "returns brainstorming with existing user that was already added", %{
      brainstorming: brainstorming
    } do
      already_included_user = brainstorming.users |> List.first()

      brainstorming = brainstorming |> Accounts.merge_brainstorming_user(already_included_user.id)

      assert already_included_user.id in (brainstorming.users |> Enum.map(& &1.id))
      assert Repo.aggregate(User, :count) == 2

      assert Repo.one(
               from bd in BrainstormingUser,
                 where: bd.brainstorming_id == ^brainstorming.id,
                 select: count(bd.id)
             ) == 1

      assert Repo.one(
               from bd in BrainstormingUser,
                 where: bd.user_id == ^already_included_user.id,
                 select: count(bd.id)
             ) == 1
    end

    test "returns brainstorming with new user created and added", %{
      brainstorming: brainstorming
    } do
      new_user_id = Ecto.UUID.generate()
      brainstorming = brainstorming |> Accounts.merge_brainstorming_user(new_user_id)

      assert new_user_id in (brainstorming.users |> Enum.map(& &1.id))

      assert Repo.get!(User, new_user_id)
      assert Repo.aggregate(User, :count) == 3

      assert Repo.one(
               from bd in BrainstormingUser,
                 where: bd.brainstorming_id == ^brainstorming.id,
                 select: count(bd.id)
             ) == 2

      assert Repo.one(
               from bd in BrainstormingUser,
                 where: bd.user_id == ^new_user_id,
                 select: count(bd.id)
             ) == 1
    end

    test "returns brainstorming when nil is given", %{brainstorming: brainstorming} do
      assert brainstorming == brainstorming |> Accounts.merge_brainstorming_user(nil)
    end

    test "returns brainstorming when invalid uuid is given", %{brainstorming: brainstorming} do
      invalid_uuid = "12345-some-invalid-uuid-67890"
      assert brainstorming == brainstorming |> Accounts.merge_brainstorming_user(invalid_uuid)
    end
  end
end
