defmodule Mindwendel.AccountsTest do
  use Mindwendel.DataCase
  alias Mindwendel.Factory
  alias Mindwendel.Accounts
  alias Mindwendel.Accounts.User

  setup do
    %{user: Factory.insert!(:user)}
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
      assert existing_user |> Repo.preload(:brainstormings) ==
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
end
