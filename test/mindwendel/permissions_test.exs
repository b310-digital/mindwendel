defmodule Mindwendel.PermissionsTest do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory
  alias Mindwendel.Accounts
  alias Mindwendel.Permissions

  describe "has_moderating_permission" do
    test "returns true if user is moderating" do
      moderating_user = Factory.insert!(:user)
      brainstorming = Factory.insert!(:brainstorming)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      assert Permissions.has_moderating_permission(
               brainstorming.id,
               Accounts.get_user(moderating_user.id)
             )
    end

    test "returns false if user is not moderating" do
      user = Factory.insert!(:user)
      brainstorming = Factory.insert!(:brainstorming)
      refute Permissions.has_moderating_permission(brainstorming.id, Accounts.get_user(user.id))
    end

    test "returns false if user is nil" do
      brainstorming = Factory.insert!(:brainstorming)
      refute Permissions.has_moderating_permission(brainstorming.id, nil)
    end
  end
end
