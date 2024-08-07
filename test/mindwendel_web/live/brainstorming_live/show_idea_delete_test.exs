defmodule MindwendelWeb.BrainstormingLive.ShowIdeaDeleteTest do
  use MindwendelWeb.ConnCase
  use Mindwendel.ChatCompletionsCase
  import Phoenix.LiveViewTest
  alias Mindwendel.Brainstormings

  alias Mindwendel.Factory

  setup %{conn: conn} do
    disable_ai()
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

  # <%= link to: "#", class: "float-end ms-3 mb-3", phx_click: "delete", phx_target: @myself, phx_value_id: idea.id, title: 'Delete', data: [confirm: gettext("Are you sure you want to delete this idea?")] do %>
  #               <i class="bi bi-x text-secondary"></i>
  #             <% end %>

  test "delete idea as moderating user", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    moderating_user = Factory.insert!(:user)
    Brainstormings.add_moderating_user(brainstorming, moderating_user)

    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

    show_live_view
    |> element(html_selector_button_idea_delete_link())
    |> render_click()

    refute show_live_view
           |> element(html_selector_button_idea_delete_link())
           |> has_element?

    # refute rendered =~ 'Delete'

    # {:ok, show_live_view, _html} =
    #   conn
    #   |> init_test_session(%{current_user_id: moderatoring_user.id})
    #   |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

    # refute show_live_view
    #        |> element(html_selector_button_idea_delete_link())
    #        |> has_element?

    # new_idea_body = "New idea body by moderatoring user"

    # {:ok, show_live_view, _html} =
    #   show_live_view
    #   |> form("#idea-form", idea: %{body: new_idea_body})
    #   |> render_submit()
    #   |> follow_redirect(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    # assert show_live_view
    #        |> element(".card-body-mindwendel-idea", new_idea_body)
    #        |> has_element?
  end

  defp html_selector_button_idea_delete_link do
    "a[@title='Delete']"
  end
end
