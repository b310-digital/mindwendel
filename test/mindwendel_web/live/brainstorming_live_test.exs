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

    test "shows all ideas that belong to brainstorming", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)

      brainstorming_ideas =
        Enum.map(0..2, fn _ -> Factory.insert!(:idea, %{brainstorming: brainstorming}) end)

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      Enum.each(brainstorming_ideas, fn brainstorming_idea ->
        assert show_live_view
               |> has_element?(html_selector_idea_card(brainstorming_idea))
      end)
    end

    test "shows all labels associated to the brainstorming", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)
      Factory.insert!(:idea, %{brainstorming: brainstorming})

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      Enum.each(brainstorming.labels, fn brainstorming_idea_label ->
        assert show_live_view
               |> has_element?(html_selector_idea_label(brainstorming_idea_label))
      end)
    end

    test "active idea label ", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)
      selected_ideal_label = Enum.at(brainstorming.labels, 0)

      idea =
        Factory.insert!(:idea, %{
          label: selected_ideal_label,
          brainstorming: brainstorming
        })

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert show_live_view
             |> has_element?(".IndexComponent__IdeaCard--active[data-testid=\"#{idea.id}\"]")

      assert show_live_view
             |> has_element?(
               ".IndexComponent__IdeaLabel--active[data-testid=\"#{selected_ideal_label.id}\"]"
             )
    end

    test "applys labels to idea", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)
      selected_ideal_label = Enum.at(brainstorming.labels, 0)
      idea = Factory.insert!(:idea, %{brainstorming: brainstorming})

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      element_selector =
        ".IndexComponent__IdeaCard[data-testid=\"#{idea.id}\"] .IndexComponent__IdeaLabelSection a[phx-value-label-id=\"#{
          selected_ideal_label.id
        }\"]"

      assert show_live_view |> has_element?(element_selector)

      show_live_view
      |> element(element_selector)
      |> render_click()

      updated_idea = Repo.reload(idea) |> Repo.preload([:label])
      assert updated_idea.label == selected_ideal_label
    end

    test "removes labels from idea", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)
      selected_ideal_label = Enum.at(brainstorming.labels, 0)

      idea =
        Factory.insert!(:idea, %{
          label: selected_ideal_label,
          brainstorming: brainstorming
        })

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      element_selector =
        ".IndexComponent__IdeaCard--active[data-testid=\"#{idea.id}\"] .IndexComponent__IdeaLabelSection a[data-testid=\"#{
          selected_ideal_label.id
        }\"]"

      assert show_live_view |> has_element?(element_selector)

      show_live_view
      |> element(element_selector)
      |> render_click()

      updated_idea = Repo.reload(idea) |> Repo.preload([:label])
      assert updated_idea.label == nil
    end
  end

  describe "new" do
    setup [:create_brainstorming]

    test "shows username in the idea creation modal", %{conn: conn, brainstorming: brainstorming} do
      {:ok, _show_live, html} =
        live(conn, Routes.brainstorming_show_path(conn, :new_idea, brainstorming))

      assert html =~ "Anonymous"
    end
  end

  defp html_selector_idea_card(idea) do
    ".IndexComponent__IdeaCard[data-testid=\"#{idea.id}\"]"
  end

  defp html_selector_idea_label(idea_label) do
    ".IndexComponent__IdeaLabel[data-testid=\"#{idea_label.id}\"]"
  end
end
