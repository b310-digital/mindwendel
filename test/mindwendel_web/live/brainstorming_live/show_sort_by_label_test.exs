defmodule MindwendelWeb.BrainstormingLive.ShowSortByLabelTest do
  use MindwendelWeb.ConnCase
  use Mindwendel.ChatCompletionsCase
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  setup do
    disable_ai()
    %{brainstorming: Factory.insert!(:brainstorming)}
  end

  test "contains button \"Sort by labels\"", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, show_live_view, _html} =
      live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

    assert show_live_view
           |> has_element?(html_selector_button_sort_by_labels(brainstorming))
  end

  # The order of the labels is the defined by the column position_order
  test "sort ideas by labels", %{conn: conn, brainstorming: brainstorming} do
    idea_with_first_label =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        label: Enum.at(brainstorming.labels, 0)
      })

    idea_with_second_label =
      Factory.insert!(:idea, %{
        brainstorming: brainstorming,
        label: Enum.at(brainstorming.labels, 1)
      })

    idea_without_label = Factory.insert!(:idea, %{brainstorming: brainstorming})

    {:ok, show_live_view, _html} =
      live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

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
