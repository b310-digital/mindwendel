defmodule MindwendelWeb.BrainstormingLive.ShowIdeaCommentTest do
  use MindwendelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Mindwendel.Accounts

  alias Mindwendel.Factory

  setup %{conn: conn} do
    brainstorming = Factory.insert!(:brainstorming)
    lane = Enum.at(brainstorming.lanes, 0)
    current_user_id = Ecto.UUID.generate()
    user = Factory.insert!(:user, id: current_user_id)

    idea =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        lane: lane,
        user_id: current_user_id
      })

    comment =
      Factory.insert!(:comment, %{
        idea: idea,
        user_id: current_user_id,
        body: "a test comment"
      })

    moderating_user = Factory.insert!(:user)
    Accounts.add_moderating_user(brainstorming, moderating_user)

    new_user = Factory.insert!(:user)

    %{
      brainstorming: brainstorming,
      current_user_id: current_user_id,
      conn: conn |> init_test_session(%{current_user_id: current_user_id}),
      idea: idea,
      user: user,
      moderating_user: moderating_user,
      new_user: new_user,
      lane: lane,
      comment: comment
    }
  end

  test "contains button for showing details of an idea", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, show_live_view, _html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

    assert show_live_view
           |> element(html_selector_button_idea_show_link())
           |> has_element?
  end

  test "moves to detail page after click", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, show_live_view, _html} =
      live(conn, ~p"/brainstormings/#{brainstorming.id}")

    assert show_live_view
           |> element(html_selector_button_idea_show_link())
           |> render_click()

    assert show_live_view
           |> assert_patched(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")
  end

  test "shows an existing comment", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, _show_live_view, html} =
      live(conn, ~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert html =~ "a test comment"
  end

  test "add a new comment", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, show_live_view, _html} =
      live(conn, ~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert show_live_view
           |> form("#comment-form-new", comment: %{body: "new comment"})
           |> render_submit()

    html = render(show_live_view)
    assert html =~ "new comment"
  end

  test "shows delete button", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, show_live_view, _html} =
      conn
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert show_live_view
           |> element(html_selector_button_delete())
           |> has_element?
  end

  test "pressing delete removes comment", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, show_live_view, _html} =
      conn
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert show_live_view
           |> element(html_selector_button_delete())
           |> render_click()

    refute show_live_view
           |> element(html_selector_button_delete())
           |> has_element?
  end

  test "shows the delete button for moderating user", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea,
    moderating_user: moderating_user
  } do
    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert show_live_view
           |> element(html_selector_button_delete())
           |> has_element?
  end

  test "does not show delete button for other users", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea,
    new_user: new_user
  } do
    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: new_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    refute show_live_view
           |> element(html_selector_button_delete())
           |> has_element?
  end

  test "shows edit button", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, show_live_view, _html} =
      conn
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert show_live_view
           |> element(html_selector_button_edit())
           |> has_element?
  end

  test "shows the edit button for moderating user", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea,
    moderating_user: moderating_user
  } do
    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert show_live_view
           |> element(html_selector_button_edit())
           |> has_element?
  end

  test "editing a comment", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea,
    comment: comment
  } do
    {:ok, show_live_view, _html} =
      conn
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    assert show_live_view
           |> element(html_selector_button_edit())
           |> render_click()

    assert show_live_view
           |> form("#comment-form-#{comment.id}", comment: %{body: "edited comment"})
           |> render_submit()

    html = render(show_live_view)
    assert html =~ "edited comment"
  end

  test "does not show edit button for other users", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea,
    new_user: new_user
  } do
    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: new_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    refute show_live_view
           |> element(html_selector_button_edit())
           |> has_element?
  end

  defp html_selector_button_idea_show_link do
    ".card-body-mindwendel-idea > a:nth-child(3)"
  end

  defp html_selector_button_delete do
    "a[phx-click='delete_comment']"
  end

  defp html_selector_button_edit do
    "a[phx-click='edit_comment']"
  end
end
