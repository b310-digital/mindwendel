defmodule MindwendelWeb.LiveHelpersTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  setup do
    %{brainstorming: Factory.insert!(:brainstorming)}
  end

  test "contains deletion date", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, _show_live_view, html} =
      live(conn, ~p"/brainstormings/#{brainstorming}")

    assert html =~ "in 29 days"
  end
end
