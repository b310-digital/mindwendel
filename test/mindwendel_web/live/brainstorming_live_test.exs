defmodule MindwendelWeb.BrainstormingLiveTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mindwendel.Brainstormings
  alias Mindwendel.Factory
  alias Mindwendel.Repo

  @create_attrs %{name: "a name"}

  defp fixture(:brainstorming) do
    {:ok, brainstorming} = Brainstormings.create_brainstorming(@create_attrs)
    brainstorming
  end

  defp create_brainstorming(_) do
    brainstorming = fixture(:brainstorming)
    %{brainstorming: brainstorming}
  end

  describe "Show" do
    setup [:create_brainstorming]

    test "displays brainstorming", %{conn: conn, brainstorming: brainstorming} do
      {:ok, _show_live, html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert html =~ brainstorming.name
    end

    test "shows username in the idea creation modal", %{conn: conn, brainstorming: brainstorming} do
      {:ok, _show_live, html} =
        live(conn, Routes.brainstorming_show_path(conn, :new_idea, brainstorming))

      assert html =~ "Anonymous"
    end

    test "applys labels to idea", %{conn: conn, brainstorming: brainstorming} do
      idea = Factory.insert!(:idea, %{brainstorming: brainstorming})
      brainstorming = Repo.preload(brainstorming, :ideas)

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      refute show_live_view
             |> element(
               "#idea-#{idea.id} a#idea-label-label_1 i.IndexComponent__IdeaLabel--label_1--active"
             )
             |> has_element?()

      show_live_view
      |> element("#idea-#{idea.id} a#idea-label-label_1")
      |> render_click()

      assert Repo.reload(idea).label == :label_1
    end

    test "removes labels from idea", %{conn: conn, brainstorming: brainstorming} do
      idea = Factory.insert!(:idea, %{brainstorming: brainstorming, label: :label_1})
      brainstorming = Repo.preload(brainstorming, :ideas)

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert show_live_view
             |> element(
               "#idea-#{idea.id} a#idea-label-label_1 i.IndexComponent__IdeaLabel--label_1--active"
             )
             |> has_element?()

      show_live_view
      |> element("#idea-#{idea.id} a#idea-label-label_1")
      |> render_click()

      assert Repo.reload(idea).label == nil
    end
  end
end
