defmodule MindwendelWeb.BrainstormingLive.ShowIdeaDeleteTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Mindwendel.Brainstormings

  alias Mindwendel.Factory

  setup %{conn: conn} do
    brainstorming = Factory.insert!(:brainstorming)
    current_user_id = Ecto.UUID.generate()
    user = Factory.insert!(:user, id: current_user_id)
    lane = Enum.at(brainstorming.lanes, 0)

    idea =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        user_id: current_user_id,
        lane: lane
      })

    %{
      brainstorming: brainstorming,
      current_user_id: current_user_id,
      conn: conn |> init_test_session(%{current_user_id: current_user_id}),
      idea: idea,
      user: user
    }
  end

  test "delete idea as moderating user", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    moderating_user = Factory.insert!(:user)
    Brainstormings.add_moderating_user(brainstorming, moderating_user)

    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    show_live_view
    |> element(html_selector_button_idea_delete_link())
    |> render_click()

    refute show_live_view
           |> element(html_selector_button_idea_delete_link())
           |> has_element?
  end

  test "delete idea as idea owner", %{
    conn: conn,
    brainstorming: brainstorming,
    user: user
  } do
    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    show_live_view
    |> element(html_selector_button_idea_delete_link())
    |> render_click()

    refute show_live_view
           |> element(html_selector_button_idea_delete_link())
           |> has_element?
  end

  test "does not show delete button different user", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    new_user = Factory.insert!(:user)

    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: new_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    refute show_live_view
           |> element(html_selector_button_idea_delete_link())
           |> has_element?
  end

  defp html_selector_button_idea_delete_link do
    "a[@title='Delete idea']"
  end
end
