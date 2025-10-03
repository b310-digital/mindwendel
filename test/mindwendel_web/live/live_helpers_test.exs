defmodule MindwendelWeb.LiveHelpersTest do
  use MindwendelWeb.ConnCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  setup do
    disable_ai()
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
