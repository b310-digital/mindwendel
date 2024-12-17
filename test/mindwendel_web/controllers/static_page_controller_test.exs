defmodule MindwendelWeb.StaticPageControllerTest do
  use MindwendelWeb.ConnCase, async: true

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
