defmodule Mindwendel.Accounts.UserTest do
  use Mindwendel.DataCase
  alias Mindwendel.Factory
  alias Mindwendel.Accounts.User

  describe "changeset" do
    test "username is set to Anonym when empty" do
      user = User.changeset(%User{}, %{username: ""}) |> Repo.insert!()
      assert user.username == "Anonym"
    end

    test "limits the username to 50 characters" do
      changeset = User.changeset(%User{}, %{username: String.duplicate("a", 51)})
      assert changeset.changes[:username] == String.duplicate("a", 50)
    end
  end
end
