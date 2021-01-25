defmodule MindwendelWeb.BrainstormingLiveTest do
  use MindwendelWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Mindwendel.Brainstormings

  @create_attrs %{name: "a name"}

  defp fixture(:brainstorming) do
    {:ok, brainstorming} = Brainstormings.create_brainstorming(@create_attrs)
    brainstorming
  end

  defp create_brainstorming(_) do
    brainstorming = fixture(:brainstorming)
    %{brainstorming: brainstorming}
  end

  describe "Show" do
    setup [:create_brainstorming]

    test "displays brainstorming", %{conn: conn, brainstorming: brainstorming} do
      {:ok, _show_live, html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert html =~ brainstorming.name
    end

    test "shows username in the idea creation modal", %{conn: conn, brainstorming: brainstorming} do
      {:ok, _show_live, html} =
        live(conn, Routes.brainstorming_show_path(conn, :new_idea, brainstorming))

      assert html =~ "Anonymous"
    end
  end
end
