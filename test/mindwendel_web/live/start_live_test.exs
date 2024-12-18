defmodule MindwendelWeb.StartLiveTest do
  use MindwendelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "home without current_user_id in session" do
    test "contains text", %{conn: conn} do
      {:ok, _show_live, html} = live(conn, ~p"/")

      assert html =~ "mindwendel"
      assert html =~ "Brainstorm"
    end

    test "shows a form to create a new brainstorming", %{conn: conn} do
      {:ok, _show_live, html} = live(conn, ~p"/")

      assert html =~ ~r/form.*action="\/brainstormings"/i
      assert html =~ ~r/<input/i
      assert html =~ ~r/How might we/i
      assert html =~ ~r/type="submit"/i
    end

    test "does not contain recent brainstormings", %{conn: conn} do
      {:ok, _show_live, html} = live(conn, ~p"/")

      refute html =~ "Your latest brainstorming"
    end
  end
end
