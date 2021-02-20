defmodule MindwendelWeb.StaticPageControllerTest do
  use MindwendelWeb.ConnCase
  alias Mindwendel.Factory
  alias Mindwendel.Repo

  describe "home without current_user_id in session" do
    test "contains text", %{conn: conn} do
      conn = get(conn, Routes.static_page_path(conn, :home))
      assert html_response(conn, 200) =~ "mindwendel"
    end

    test "sets current_user_id in session", %{conn: conn} do
      conn = get(conn, Routes.static_page_path(conn, :home))
      refute MindwendelService.SessionService.get_current_user_id(conn) == nil
    end

    test "does not contain recent brainstormings", %{conn: conn} do
      conn = get(conn, Routes.static_page_path(conn, :home))
      refute html_response(conn, 200) =~ "Your latest brainstorming"
    end
  end

  describe "home with current_user in session and without brainstormings" do
    setup do
      brainstorming =
        Factory.insert!(:brainstorming, :with_users)
        |> Repo.preload(:users)

      %{brainstorming: brainstorming}
    end

    test "shows brainstormings associated to user", %{conn: conn, brainstorming: brainstorming} do
      user = brainstorming.users |> List.first()

      conn =
        init_test_session(conn, %{
          MindwendelService.SessionService.session_key_current_user_id() => user.id
        })

      conn = get(conn, Routes.static_page_path(conn, :home))

      assert html_response(conn, 200) =~ "Deine letzten Brainstormings"
      assert html_response(conn, 200) =~ brainstorming.name
    end

    test "does not show brainstorming when current user does not have any brainstomrings associated",
         %{conn: conn, brainstorming: brainstorming} do
      user = Factory.insert!(:user)

      conn =
        init_test_session(conn, %{
          MindwendelService.SessionService.session_key_current_user_id() => user.id
        })

      conn = get(conn, Routes.static_page_path(conn, :home))

      refute html_response(conn, 200) =~ "Deine letzten Brainstormings"
      refute html_response(conn, 200) =~ brainstorming.name
    end
  end
end
