defmodule MindwendelWeb.StaticPageControllerTest do
  use MindwendelWeb.ConnCase
  alias Mindwendel.Factory
  alias Mindwendel.Repo

  describe "home without current_user_id in session" do
    test "contains text", %{conn: conn} do
      html =
        conn
        |> get(~p"/")
        |> html_response(200)

      assert html =~ "mindwendel"
      assert html =~ "Brainstorm"
    end

    test "sets current_user_id in session", %{conn: conn} do
      conn = get(conn, ~p"/")
      refute Mindwendel.Services.SessionService.get_current_user_id(conn) == nil
    end

    test "does not contain recent brainstormings", %{conn: conn} do
      conn = get(conn, ~p"/")
      refute html_response(conn, 200) =~ "Your latest brainstorming"
    end

    test "shows a form to create a new brainstorming", %{conn: conn} do
      html =
        conn
        |> get(~p"/")
        |> html_response(200)

      assert html =~ ~r/form.*action="\/brainstormings"/i
      assert html =~ ~r/<input/i
      assert html =~ ~r/How might we/i
      assert html =~ ~r/type="submit"/i
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
          Mindwendel.Services.SessionService.session_key_current_user_id() => user.id
        })

      html =
        conn
        |> get(~p"/")
        |> html_response(200)

      assert html =~ "Your latest brainstormings"
      assert html =~ brainstorming.name
    end

    test "does not show brainstorming when current user does not have any brainstomrings associated",
         %{conn: conn, brainstorming: brainstorming} do
      user = Factory.insert!(:user)

      conn =
        init_test_session(conn, %{
          Mindwendel.Services.SessionService.session_key_current_user_id() => user.id
        })

      html =
        conn
        |> get(~p"/")
        |> html_response(200)

      refute html =~ "Your latest brainstormings"
      refute html =~ brainstorming.name
    end

    test "shows a form to create a new brainstorming", %{conn: conn} do
      html =
        conn
        |> get(~p"/")
        |> html_response(200)

      assert html =~ ~r/form.*action="\/brainstormings"/i
      assert html =~ ~r/<input/i
      assert html =~ ~r/How might we/i
      assert html =~ ~r/type="submit"/i
    end
  end
end
