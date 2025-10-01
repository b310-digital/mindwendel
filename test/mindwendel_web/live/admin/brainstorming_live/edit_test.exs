defmodule MindwendelWeb.Admin.BrainstormingLive.EditTest do
  use MindwendelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  alias Mindwendel.Brainstormings
  alias Mindwendel.Lanes

  setup do
    brainstorming = Factory.insert!(:brainstorming)

    %{
      brainstorming: brainstorming,
      idea:
        Factory.insert!(:idea, brainstorming: brainstorming, inserted_at: ~N[2021-01-01 15:04:30])
    }
  end

  test "connected mount", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

    assert render(edit_live_view) =~ brainstorming.name
  end

  test "submit new brainstorming name", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

    assert edit_live_view
           |> element("form#form-edit-brainstorming")
           |> render_submit(%{
             brainstorming: %{name: "New brainstorming name"}
           }) =~
             "New brainstorming name"
  end

  test "renders five idea labels for brainstorming", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

    assert edit_live_view |> element("input#brainstorming_labels_0_name") |> has_element?
    assert edit_live_view |> element("input#brainstorming_labels_1_name") |> has_element?
    assert edit_live_view |> element("input#brainstorming_labels_2_name") |> has_element?
    assert edit_live_view |> element("input#brainstorming_labels_3_name") |> has_element?
    assert edit_live_view |> element("input#brainstorming_labels_4_name") |> has_element?
    refute edit_live_view |> element("input#brainstorming_labels_5_name") |> has_element?
  end

  test "adds and immediately saves new idea label", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

    edit_live_view
    |> element("button", "Add idea label")
    |> render_click()

    assert edit_live_view |> element("input#brainstorming_labels_5_name") |> has_element?
    refute edit_live_view |> element("input#brainstorming_labels_6_name") |> has_element?

    edit_live_view
    |> element("button", "Add idea label")
    |> render_click()

    assert edit_live_view |> element("input#brainstorming_labels_6_name") |> has_element?
  end

  test "saves input changes to label", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

    assert edit_live_view
           |> form("#form-labels", %{brainstorming: %{labels: %{"0": %{name: "new label"}}}})
           |> render_change()

    {:ok, brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)

    assert brainstorming.labels
           |> Enum.map(fn a -> a.name end)
           |> Enum.member?("new label")
  end

  test "removes idea label", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

    brainstorming_label_first = Enum.at(brainstorming.labels, 0)

    edit_live_view
    |> element("button[value=\"#{brainstorming_label_first.id}\"]", "Remove")
    |> render_click()

    assert edit_live_view |> element("input#brainstorming_labels_0_name") |> has_element?

    refute edit_live_view
           |> element("button[value=\"#{brainstorming_label_first.id}\"]", "Remove")
           |> has_element?

    refute edit_live_view |> element("input#brainstorming_labels_4_name") |> has_element?
  end

  test "does not remove idea label when idea is attached to this label", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    brainstorming_label_first = Enum.at(brainstorming.labels, 0)

    _idea =
      Factory.insert!(:idea,
        brainstorming: brainstorming,
        idea_labels: [
          brainstorming_label_first
        ]
      )

    {:ok, edit_live_view, _html} =
      live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

    assert edit_live_view
           |> element(html_selector_remove_idea_label_button(brainstorming_label_first), "Remove")
           |> render_click()

    # It should still be there because the idea label is still connected iwth an idea and therefore cannot be deleted.

    # assert edit_live_view
    #        |> element(".invalid-tooltip", "This label is associated with an idea")
    #        |> has_element?()

    assert edit_live_view
           |> element("input[type=hidden][value=\"#{brainstorming_label_first.id}\"]")
           |> has_element?

    assert edit_live_view
           |> element(html_selector_remove_idea_label_button(brainstorming_label_first), "Remove")
           |> has_element?

    assert edit_live_view |> element("input#brainstorming_labels_0_name") |> has_element?

    assert edit_live_view |> element("input#brainstorming_labels_4_name") |> has_element?
  end

  describe "empty brainstorming" do
    test "handles empty event to delete brainstorming content", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      {:ok, edit_live_view, _html} =
        live(conn, ~p"/admin/brainstormings/#{brainstorming.admin_url_id}/edit")

      # reload brainstorming to check for changes:
      lanes = Lanes.get_lanes_for_brainstorming(brainstorming.id)
      assert length(lanes) == 1

      edit_live_view
      |> element("button", "Empty")
      |> render_click()

      # reload brainstorming to check for changes:
      lanes = Lanes.get_lanes_for_brainstorming(brainstorming.id)
      assert lanes == []
    end
  end

  defp html_selector_remove_idea_label_button(idea_label) do
    "button[value=\"#{idea_label.id}\"]"
  end
end
