defmodule MindwendelWeb.BrainstormingLive.ShowIdeaEditTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Mindwendel.Brainstormings
  alias Mindwendel.Accounts.User

  alias Mindwendel.Factory

  setup %{conn: conn} do
    brainstorming = Factory.insert!(:brainstorming)
    current_user_id = Ecto.UUID.generate()
    user = Factory.insert!(:user, id: current_user_id)

    idea =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        user_id: current_user_id
      })

    %{
      brainstorming: brainstorming,
      current_user_id: current_user_id,
      conn: conn |> init_test_session(%{current_user_id: current_user_id}),
      idea: idea,
      user: user
    }
  end

  test "contains button for editing ideas", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, show_live_view, _html} =
      live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> element(html_selector_button_idea_edit_link())
           |> has_element?
  end

  test "moves to after click", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    {:ok, show_live_view, _html} =
      live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> element(html_selector_button_idea_edit_link())
           |> render_click()

    assert show_live_view
           |> assert_patched(
             Routes.brainstorming_show_path(conn, :edit_idea, brainstorming, idea)
           )
  end

  test "edit and update text", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, show_live_view, _html} =
      live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> element(html_selector_button_idea_edit_link())
           |> render_click()

    new_idea_body = "New idea body"

    {:ok, show_live_view, _html} =
      show_live_view
      |> form("#idea-form", idea: %{body: new_idea_body})
      |> render_submit()
      |> follow_redirect(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> element(".card-body-mindwendel-idea", new_idea_body)
           |> has_element?
  end

  test "edit and update text as moderatoring user", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    moderatoring_user = Factory.insert!(:user)
    Brainstormings.add_moderating_user(brainstorming, moderatoring_user)

    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderatoring_user.id})
      |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> element(html_selector_button_idea_edit_link())
           |> render_click()

    new_idea_body = "New idea body by moderator"

    {:ok, show_live_view, _html} =
      show_live_view
      |> form("#idea-form", idea: %{body: new_idea_body})
      |> render_submit()
      |> follow_redirect(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

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
      |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> element(html_selector_button_idea_edit_link())
           |> render_click()

    new_idea_body = "New idea body by moderator"

    {:ok, show_live_view, _html} =
      show_live_view
      |> form("#idea-form", idea: %{body: new_idea_body})
      |> render_submit()
      |> follow_redirect(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> element(".card-body-mindwendel-idea", new_idea_body)
           |> has_element?

    assert Mindwendel.Brainstormings.get_idea!(idea.id).user_id
    assert moderator_user.id != Mindwendel.Brainstormings.get_idea!(idea.id).user_id
    assert user_id = Mindwendel.Brainstormings.get_idea!(idea.id).user_id
  end

  defp html_selector_button_idea_edit_link do
    "a[@title='Edit Idea']"
  end
end
