defmodule MindwendelWeb.BrainstormingLive.ShowIdeaEditTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Mindwendel.Brainstormings
  alias Mindwendel.Accounts.User

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

    %{
      brainstorming: brainstorming,
      current_user_id: current_user_id,
      conn: conn |> init_test_session(%{current_user_id: current_user_id}),
      idea: idea,
      user: user,
      lane: lane
    }
  end

  test "contains button for editing ideas", %{
    conn: conn,
    brainstorming: brainstorming,
    user: user
  } do
    Brainstormings.add_moderating_user(brainstorming, user)
    {:ok, show_live_view, _html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

    assert show_live_view
           |> element(html_selector_button_idea_edit_link())
           |> has_element?
  end

  test "moves to after click", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea,
    user: user
  } do
    Brainstormings.add_moderating_user(brainstorming, user)

    {:ok, show_live_view, _html} =
      live(conn, ~p"/brainstormings/#{brainstorming.id}")

    assert show_live_view
           |> element(html_selector_button_idea_edit_link())
           |> render_click()

    assert show_live_view
           |> assert_patched(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}/edit")
  end

  test "edit and update text", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, show_live_view, _html} =
      live(conn, ~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}/edit")

    new_idea_body = "New idea body"

    assert show_live_view
           |> form("#idea-form", idea: %{body: new_idea_body})
           |> render_submit()

    assert_patch(show_live_view, ~p"/brainstormings/#{brainstorming.id}")

    html = render(show_live_view)
    assert html =~ new_idea_body
  end

  test "edit and update text as moderatoring user", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    moderatoring_user = Factory.insert!(:user)
    Brainstormings.add_moderating_user(brainstorming, moderatoring_user)

    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderatoring_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}/edit")

    new_idea_body = "New idea body by moderator"

    assert show_live_view
           |> form("#idea-form", idea: %{body: new_idea_body})
           |> render_submit()

    assert_patch(show_live_view, ~p"/brainstormings/#{brainstorming.id}")

    assert show_live_view
           |> element(".card-body-mindwendel-idea", new_idea_body)
           |> has_element?
  end

  test "does not change user owner of idea after updating text as moderator user", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea,
    user: %User{id: user_id}
  } do
    moderator_user = Factory.insert!(:user)
    Brainstormings.add_moderating_user(brainstorming, moderator_user)

    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderator_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}/edit")

    new_idea_body = "New idea body by moderator"

    assert show_live_view
           |> form("#idea-form", idea: %{body: new_idea_body})
           |> render_submit()

    assert_patch(show_live_view, ~p"/brainstormings/#{brainstorming.id}")

    assert show_live_view
           |> element(".card-body-mindwendel-idea", new_idea_body)
           |> has_element?

    assert Mindwendel.Ideas.get_idea!(idea.id).user_id
    assert moderator_user.id != Mindwendel.Ideas.get_idea!(idea.id).user_id
    assert ^user_id = Mindwendel.Ideas.get_idea!(idea.id).user_id
  end

  defp html_selector_button_idea_edit_link() do
    ".card-body-mindwendel-idea > a:nth-child(2)"
  end
end
