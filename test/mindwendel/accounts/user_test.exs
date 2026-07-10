defmodule Mindwendel.Accounts.UserTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Accounts.User

  describe "changeset/2" do
    test "defaults empty username to Anonymous" do
      changeset = User.changeset(%User{username: "OldName"}, %{username: ""})
      assert Ecto.Changeset.get_field(changeset, :username) == "Anonymous"
    end

    test "defaults whitespace-only username to Anonymous" do
      changeset = User.changeset(%User{username: "OldName"}, %{username: "   "})
      assert Ecto.Changeset.get_field(changeset, :username) == "Anonymous"
    end

    test "preserves non-empty username" do
      changeset = User.changeset(%User{username: "OldName"}, %{username: "Alice"})
      assert Ecto.Changeset.get_field(changeset, :username) == "Alice"
    end

    test "does not change username when not provided" do
      changeset = User.changeset(%User{username: "Existing"}, %{})
      assert Ecto.Changeset.get_field(changeset, :username) == "Existing"
    end
  end
end
