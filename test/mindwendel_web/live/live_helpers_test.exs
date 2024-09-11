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

  test "contains sort button by likes for admin", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    moderating_user = Factory.insert!(:user)
    Brainstormings.add_moderating_user(brainstorming, moderating_user)

    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert view |> has_element?(".btn[title|='Sort by likes']")
  end

  test "does not contain sort button by default for user", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, view, _html} =
      conn
      |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

    refute view |> has_element?(".btn[title|='Sort by likes']")
  end
end
