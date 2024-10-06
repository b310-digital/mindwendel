defmodule MindwendelWeb.BrainstormingLive.ShowSortByLabelTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Mindwendel.Brainstormings

  alias Mindwendel.Factory

  setup do
    moderating_user = Factory.insert!(:user)
    brainstorming = Factory.insert!(:brainstorming)
    Brainstormings.add_moderating_user(brainstorming, moderating_user)
    %{brainstorming: brainstorming, moderating_user: moderating_user}
  end

  test "contains button \"Sort by labels\"", %{
    conn: conn,
    brainstorming: brainstorming,
    moderating_user: moderating_user
  } do
    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    assert show_live_view
           |> has_element?(html_selector_button_sort_by_labels(brainstorming))
  end

  # The order of the labels is the defined by the column position_order
  test "sort ideas by labels", %{
    conn: conn,
    brainstorming: brainstorming,
    moderating_user: moderating_user
  } do
    idea_with_first_label =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        label: Enum.at(brainstorming.labels, 0),
        lane: Enum.at(brainstorming.lanes, 0)
      })

    idea_with_second_label =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        label: Enum.at(brainstorming.labels, 1),
        lane: Enum.at(brainstorming.lanes, 0)
      })

    idea_without_label =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        lane: Enum.at(brainstorming.lanes, 0)
      })

    {:ok, show_live_view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    rendered =
      show_live_view
      |> element(html_selector_button_sort_by_labels(brainstorming))
      |> render_click()

    # We would like to assert also the order of the labels but we could not find a way to do this.
    # Instead, we just assert for main elements that are supposed to be on the page.
    # However, we included some tests in test/mindwendel/brainstormings_test.exs
    assert rendered =~ brainstorming.name
    assert rendered =~ idea_with_first_label.body
    assert rendered =~ idea_with_second_label.body
    assert rendered =~ idea_without_label.body
  end

  defp html_selector_button_sort_by_labels(brainstorming) do
    "a[phx-click=\"sort_by_label\"][phx-value-id=\"#{brainstorming.id}\"]"
  end
end
