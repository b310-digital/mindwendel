defmodule MindwendelWeb.PageLiveTest do
  use MindwendelWeb.ConnCase

  import Phoenix.LiveViewTest

  @tag :skip
  test "disconnected and connected render", %{conn: conn} do
    {:ok, page_live, disconnected_html} = live(conn, "/")
    assert disconnected_html =~ "Listing Brainstormings"
    assert render(page_live) =~ "Listing Brainstormings"
  end
end
