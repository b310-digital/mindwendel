defmodule MindwendelWeb.LiveHelpersTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Mindwendel.Brainstormings

  alias Mindwendel.Factory

  setup do
    %{brainstorming: Factory.insert!(:brainstorming)}
  end

  test "contains deletion date", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, _show_live_view, html} =
      live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert html =~ "in 29 days"
  end
end
