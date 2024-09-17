defmodule MindwendelWeb.LaneLiveTest do
  use MindwendelWeb.ConnCase

  import Phoenix.LiveViewTest
  import Mindwendel.BrainstormingsFixtures

  @create_attrs %{name: "some name", position_order: 42}
  @update_attrs %{name: "some updated name", position_order: 43}
  @invalid_attrs %{name: nil, position_order: nil}

  defp create_lane(_) do
    lane = lane_fixture()
    %{lane: lane}
  end

  describe "Index" do
    setup [:create_lane]

    test "lists all lanes", %{conn: conn, lane: lane} do
      {:ok, _index_live, html} = live(conn, ~p"/lanes")

      assert html =~ "Listing Lanes"
      assert html =~ lane.name
    end

    test "saves new lane", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/lanes")

      assert index_live |> element("a", "New Lane") |> render_click() =~
               "New Lane"

      assert_patch(index_live, ~p"/lanes/new")

      assert index_live
             |> form("#lane-form", lane: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#lane-form", lane: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/lanes")

      html = render(index_live)
      assert html =~ "Lane created successfully"
      assert html =~ "some name"
    end

    test "updates lane in listing", %{conn: conn, lane: lane} do
      {:ok, index_live, _html} = live(conn, ~p"/lanes")

      assert index_live |> element("#lanes-#{lane.id} a", "Edit") |> render_click() =~
               "Edit Lane"

      assert_patch(index_live, ~p"/lanes/#{lane}/edit")

      assert index_live
             |> form("#lane-form", lane: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#lane-form", lane: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/lanes")

      html = render(index_live)
      assert html =~ "Lane updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes lane in listing", %{conn: conn, lane: lane} do
      {:ok, index_live, _html} = live(conn, ~p"/lanes")

      assert index_live |> element("#lanes-#{lane.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#lanes-#{lane.id}")
    end
  end

  describe "Show" do
    setup [:create_lane]

    test "displays lane", %{conn: conn, lane: lane} do
      {:ok, _show_live, html} = live(conn, ~p"/lanes/#{lane}")

      assert html =~ "Show Lane"
      assert html =~ lane.name
    end

    test "updates lane within modal", %{conn: conn, lane: lane} do
      {:ok, show_live, _html} = live(conn, ~p"/lanes/#{lane}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Lane"

      assert_patch(show_live, ~p"/lanes/#{lane}/show/edit")

      assert show_live
             |> form("#lane-form", lane: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#lane-form", lane: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/lanes/#{lane}")

      html = render(show_live)
      assert html =~ "Lane updated successfully"
      assert html =~ "some updated name"
    end
  end
end
