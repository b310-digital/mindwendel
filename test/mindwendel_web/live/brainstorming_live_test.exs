defmodule MindwendelWeb.BrainstormingLiveTest do
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mindwendel.Brainstormings
  alias Mindwendel.Factory
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Repo

  @create_attrs %{name: "a name"}

  defp fixture(:brainstorming) do
    user = Factory.insert!(:user)
    {:ok, brainstorming} = Brainstormings.create_brainstorming(user, @create_attrs)
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

    test "shows ideas belonging to brainstorming", %{conn: conn} do
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

    test "show active idea label ", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)
      selected_ideal_label = Enum.at(brainstorming.labels, 0)

      _idea =
        Factory.insert!(:idea, %{
          idea_labels: [selected_ideal_label],
          brainstorming: brainstorming
        })

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert show_live_view
             |> has_element?(html_selector_idea_label_badge(selected_ideal_label))

      assert show_live_view
             |> has_element?(html_selector_idea_label_active(selected_ideal_label))
    end

    test "applys labels to idea", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)
      selected_ideal_label = Enum.at(brainstorming.labels, 0)
      idea = Factory.insert!(:idea, %{brainstorming: brainstorming})

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      element_selector =
        "#{html_selector_idea_card(idea)} #{html_selector_add_idea_label_to_idea_link(selected_ideal_label)}"

      assert show_live_view |> has_element?(element_selector)

      show_live_view
      |> element(element_selector)
      |> render_click()

      updated_idea = Repo.reload(idea) |> Repo.preload([:idea_labels])
      assert updated_idea.idea_labels |> Enum.at(0) == selected_ideal_label
    end

    test "removes labels from idea", %{conn: conn} do
      brainstorming = Factory.insert!(:brainstorming)
      selected_ideal_label = Enum.at(brainstorming.labels, 0)

      idea =
        Factory.insert!(:idea, %{
          idea_labels: [selected_ideal_label],
          brainstorming: brainstorming
        })

      {:ok, show_live_view, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      element_selector =
        "#{html_selector_idea_card(idea)} #{html_selector_remove_idea_label_from_idea_link(selected_ideal_label)}"

      assert show_live_view |> has_element?(element_selector)

      show_live_view
      |> element(element_selector)
      |> render_click()

      updated_idea = Repo.reload(idea) |> Repo.preload([:idea_labels])
      assert updated_idea.idea_labels |> Enum.empty?()
    end

    test "updates last_accessed_at date", %{conn: conn, brainstorming: brainstorming} do
      {:ok, _show_live, _html} =
        live(conn, Routes.brainstorming_show_path(conn, :show, brainstorming))

      brainstorming_refreshed = Repo.get(Brainstorming, brainstorming.id)
      assert brainstorming_refreshed.last_accessed_at > brainstorming.last_accessed_at
    end

    test "enables dragging for admin", %{conn: conn, brainstorming: brainstorming} do
      moderating_user = List.first(brainstorming.users)
      Brainstormings.add_moderating_user(brainstorming, moderating_user)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert view |> has_element?("#ideas[data-sortable-enabled|='true']")
    end

    test "disables dragging for user", %{conn: conn, brainstorming: brainstorming} do
      {:ok, view, _html} =
        conn
        |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert view |> has_element?("#ideas[data-sortable-enabled|='false']")
    end

    test "enables dragging for user when option is activated", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      Brainstormings.update_brainstorming(brainstorming, %{option_allow_manual_ordering: true})

      {:ok, view, _html} =
        conn
        |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert view |> has_element?("#ideas[data-sortable-enabled|='true']")
    end

    test "contains sort button by likes for admin", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      moderating_user = List.first(brainstorming.users)
      Brainstormings.add_moderating_user(brainstorming, moderating_user)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert view |> has_element?(".btn[title|='Sort by likes']")
    end

    test "does not contain sort button by default for user", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      {:ok, view, _html} =
        conn
        |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

      refute view |> has_element?(".btn[title|='Sort by likes']")
    end

    test "contains sort button for user when option is activated", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      Brainstormings.update_brainstorming(brainstorming, %{option_allow_manual_ordering: true})

      {:ok, view, _html} =
        conn
        |> live(Routes.brainstorming_show_path(conn, :show, brainstorming))

      assert view |> has_element?(".btn[title|='Sort by likes']")
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

  defp html_selector_idea_label_badge(idea_label) do
    ".IndexComponent__IdeaLabelBadge[data-testid=\"#{idea_label.id}\"]"
  end

  defp html_selector_add_idea_label_to_idea_link(idea_label) do
    "a[data-testid=\"#{idea_label.id}\"][phx-click=\"add_idea_label_to_idea\"]"
  end

  defp html_selector_remove_idea_label_from_idea_link(idea_label) do
    "a[data-testid=\"#{idea_label.id}\"][phx-click=\"remove_idea_label_from_idea\"]"
  end

  defp html_selector_idea_label(idea_label) do
    ".IndexComponent__IdeaLabel[data-testid=\"#{idea_label.id}\"]"
  end

  defp html_selector_idea_label_active(idea_label) do
    ".IndexComponent__IdeaLabel--active[data-testid=\"#{idea_label.id}\"]"
  end
end
