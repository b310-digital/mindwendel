defmodule MindwendelWeb.BrainstormingControllerTest do
  use MindwendelWeb.ConnCase

  import Ecto.Query

  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Brainstorming

  describe "create" do
    @valid_attrs %{name: "How might we fix this?"}

    test "creates brainstormings successfully", %{conn: conn} do
      post(conn, Routes.brainstorming_path(conn, :create), brainstorming: @valid_attrs)

      assert Repo.one(Brainstorming).name == @valid_attrs.name
      assert Repo.one(from b in Brainstorming, select: count(b.id)) == 1
    end

    test "redirects to brainstorming show", %{conn: conn} do
      conn = post(conn, Routes.brainstorming_path(conn, :create), brainstorming: @valid_attrs)

      assert redirected_to(conn) =~
               Routes.brainstorming_show_path(conn, :show, Repo.one(Brainstorming))
    end
  end
end
