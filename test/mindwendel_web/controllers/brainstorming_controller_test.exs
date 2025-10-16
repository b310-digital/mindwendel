defmodule MindwendelWeb.BrainstormingControllerTest do
  use MindwendelWeb.ConnCase, async: true

  import Ecto.Query

  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Repo

  describe "create" do
    @valid_attrs %{name: "How might we fix this?"}

    test "creates brainstormings successfully", %{conn: conn} do
      post(conn, ~p"/brainstormings", brainstorming: @valid_attrs)

      assert Repo.one(Brainstorming).name == @valid_attrs.name
      assert Repo.one(from b in Brainstorming, select: count(b.id)) == 1
    end

    test "adds current user as moderating user to the brainstorming", %{conn: conn} do
      post(conn, ~p"/brainstormings", brainstorming: @valid_attrs)

      assert %Brainstorming{moderating_users: [%User{id: _}]} =
               Repo.one(Brainstorming) |> Repo.preload(:moderating_users)
    end

    test "redirects to brainstorming show", %{conn: conn} do
      conn = post(conn, ~p"/brainstormings", brainstorming: @valid_attrs)

      assert redirected_to(conn) =~
               ~p"/brainstormings/#{Repo.one(Brainstorming).id}"
    end
  end
end
