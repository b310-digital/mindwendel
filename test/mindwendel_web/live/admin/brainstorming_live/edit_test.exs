defmodule MindwendelWeb.Admin.BrainstormingLive.EditTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  setup do
    %{brainstorming: Factory.insert!(:brainstorming)}
  end

  test "connected mount", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, Routes.admin_brainstorming_edit_path(conn, :edit, brainstorming.admin_url_id))

    assert render(edit_live_view) =~ brainstorming.name
  end

  test "submit new brainstorming name", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, Routes.admin_brainstorming_edit_path(conn, :edit, brainstorming.admin_url_id))

    assert edit_live_view
           |> element("form")
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
      live(conn, Routes.admin_brainstorming_edit_path(conn, :edit, brainstorming.admin_url_id))

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
      live(conn, Routes.admin_brainstorming_edit_path(conn, :edit, brainstorming.admin_url_id))

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

  test "removes idea label", %{
    conn: conn,
    brainstorming: brainstorming
  } do
    {:ok, edit_live_view, _html} =
      live(conn, Routes.admin_brainstorming_edit_path(conn, :edit, brainstorming.admin_url_id))

    brainstorming_label_first = Enum.at(brainstorming.labels, 0)

    edit_live_view
    |> element("button[value=#{brainstorming_label_first.id}]", "Remove")
    |> render_click()

    assert edit_live_view |> element("input#brainstorming_labels_0_name") |> has_element?

    refute edit_live_view
           |> element("button[value=#{brainstorming_label_first.id}]", "Remove")
           |> has_element?

    refute edit_live_view |> element("input#brainstorming_labels_4_name") |> has_element?
  end
end
