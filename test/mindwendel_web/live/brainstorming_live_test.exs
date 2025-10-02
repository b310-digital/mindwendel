defmodule MindwendelWeb.BrainstormingLiveTest do
  use MindwendelWeb.ConnCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true
  import Phoenix.LiveViewTest

  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.Factory
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Repo

  setup do
    disable_ai()
  end

  import Mindwendel.BrainstormingsFixtures
  import Mindwendel.IdeasFixtures

  defp create_brainstorming(_) do
    brainstorming = brainstorming_fixture()
    lane = Enum.at(brainstorming.lanes, 0)
    %{brainstorming: brainstorming, lane: lane}
  end

  describe "Show" do
    setup [:create_brainstorming]

    test "displays brainstorming", %{conn: conn, brainstorming: brainstorming} do
      {:ok, _show_live, html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert html =~ brainstorming.name
    end

    test "shows ideas belonging to brainstorming", %{conn: conn} do
      brainstorming = brainstorming_fixture()

      brainstorming_ideas =
        Enum.map(0..2, fn _ ->
          idea_fixture(%{
            brainstorming_id: brainstorming.id,
            lane_id: List.first(brainstorming.lanes).id
          })
        end)

      {:ok, show_live_view, _html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}")

      Enum.each(brainstorming_ideas, fn brainstorming_idea ->
        assert show_live_view
               |> has_element?(html_selector_idea_card(brainstorming_idea))
      end)
    end

    test "shows all labels associated to the brainstorming", %{conn: conn} do
      brainstorming = brainstorming_fixture()

      idea_fixture(%{
        brainstorming_id: brainstorming.id,
        lane_id: List.first(brainstorming.lanes).id
      })

      {:ok, show_live_view, _html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}")

      Enum.each(brainstorming.labels, fn brainstorming_idea_label ->
        assert has_element?(show_live_view, html_selector_idea_label(brainstorming_idea_label))

        assert has_element?(
                 show_live_view,
                 html_selector_idea_label_link(brainstorming_idea_label)
               )
      end)
    end

    test "show active idea label ", %{conn: conn} do
      brainstorming = brainstorming_fixture()
      selected_ideal_label = Enum.at(brainstorming.labels, 0)
      lane = Enum.at(brainstorming.lanes, 0)

      _idea =
        Factory.insert!(:idea, %{
          idea_labels: [selected_ideal_label],
          brainstorming: brainstorming,
          lane: lane
        })

      {:ok, show_live_view, _html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert show_live_view
             |> has_element?(html_selector_idea_label_badge(selected_ideal_label))

      assert show_live_view
             |> has_element?(html_selector_idea_label_active(selected_ideal_label))
    end

    test "applys labels to idea", %{conn: conn} do
      brainstorming = brainstorming_fixture()
      selected_ideal_label = Enum.at(brainstorming.labels, 0)
      lane = Enum.at(brainstorming.lanes, 0)
      idea = Factory.insert!(:idea, %{brainstorming: brainstorming, lane: lane})

      {:ok, show_live_view, _html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}")

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
      brainstorming = brainstorming_fixture()
      selected_ideal_label = Enum.at(brainstorming.labels, 0)
      lane = Enum.at(brainstorming.lanes, 0)

      idea =
        Factory.insert!(:idea, %{
          idea_labels: [selected_ideal_label],
          brainstorming: brainstorming,
          lane: lane
        })

      {:ok, show_live_view, _html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}")

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
        live(conn, ~p"/brainstormings/#{brainstorming.id}")

      brainstorming_refreshed = Repo.get(Brainstorming, brainstorming.id)
      assert brainstorming_refreshed.last_accessed_at > brainstorming.last_accessed_at
    end

    test "enables dragging for admin", %{conn: conn, brainstorming: brainstorming, lane: lane} do
      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      selector = "#ideas-col-#{lane.id}[data-sortable-enabled|='true']"

      assert view |> has_element?(selector)
    end

    test "disables dragging for user", %{conn: conn, brainstorming: brainstorming, lane: lane} do
      {:ok, view, _html} =
        conn
        |> live(~p"/brainstormings/#{brainstorming.id}")

      selector = "#ideas-col-#{lane.id}[data-sortable-enabled|='false']"
      assert view |> has_element?(selector)
    end

    test "enables dragging for user when option is activated", %{
      conn: conn,
      brainstorming: brainstorming,
      lane: lane
    } do
      Brainstormings.update_brainstorming(brainstorming, %{option_allow_manual_ordering: true})

      {:ok, view, _html} =
        conn
        |> live(~p"/brainstormings/#{brainstorming.id}")

      selector = "#ideas-col-#{lane.id}[data-sortable-enabled|='true']"

      assert view |> has_element?(selector)
    end

    test "contains sort link by likes for admin", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      assert view |> has_element?("a[title|='Sort by likes']")
    end

    test "does not contain sort button by default for user", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      {:ok, view, _html} =
        conn
        |> live(~p"/brainstormings/#{brainstorming.id}")

      assert view |> has_element?("a[title|='Sort by likes'][class~= 'disabled']")
    end

    test "contains sort button for user when option is activated", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      Brainstormings.update_brainstorming(brainstorming, %{option_allow_manual_ordering: true})

      {:ok, view, _html} =
        conn
        |> live(~p"/brainstormings/#{brainstorming.id}")

      assert view |> has_element?("a[title|='Sort by likes']")
    end

    test "does not contain delete lane button for user", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      {:ok, view, _html} =
        conn
        |> live(~p"/brainstormings/#{brainstorming.id}")

      assert view |> has_element?("a[title|='Delete lane'][class~= 'disabled']")
    end

    test "does contain delete lane button for moderating user", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      assert view |> has_element?("a[title|='Delete lane']:not(.disabled)")
    end

    test "deletes the lane as moderating user", %{
      conn: conn,
      brainstorming: brainstorming,
      lane: lane
    } do
      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      view
      |> element("a[title|='Delete lane']")
      |> render_click(%{id: lane.id})

      refute view |> has_element?("div[class~= 'lane']")
    end

    test "ignores user clicks on delete lane", %{
      conn: conn,
      brainstorming: brainstorming,
      lane: lane
    } do
      {:ok, view, _html} =
        conn
        |> live(~p"/brainstormings/#{brainstorming.id}")

      view
      |> element("a[title|='Delete lane']")
      |> render_click(%{id: lane.id})

      assert view |> has_element?("div[class~= 'lane']")
    end

    test "sets a label filter as admin", %{conn: conn, brainstorming: brainstorming} do
      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)
      selected_ideal_label = Enum.at(brainstorming.labels, 0)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      view
      |> element(".btn[data-testid=\"#{selected_ideal_label.id}\"]")
      |> render_click()

      {:ok, brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)

      assert(
        brainstorming.filter_labels_ids == [
          selected_ideal_label.id
        ]
      )
    end

    test "disables label filter as user", %{conn: conn, brainstorming: brainstorming} do
      selected_ideal_label = Enum.at(brainstorming.labels, 0)

      {:ok, view, _html} =
        conn
        |> live(~p"/brainstormings/#{brainstorming.id}")

      assert view
             |> has_element?(".btn[data-testid=\"#{selected_ideal_label.id}\"][disabled]")
    end
  end

  describe "new" do
    setup [:create_brainstorming]

    test "shows username in the idea creation modal", %{
      conn: conn,
      brainstorming: brainstorming,
      lane: lane
    } do
      {:ok, _show_live, html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}/lanes/#{lane.id}/new_idea")

      assert html =~ "Anonymous"
    end

    test "updates the username after submitting an idea", %{
      conn: conn,
      brainstorming: brainstorming,
      lane: lane
    } do
      {:ok, show_live_view, _html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}/lanes/#{lane.id}/new_idea")

      assert show_live_view
             |> form("#idea-form", idea: %{username: "I am new", body: "test"})
             |> render_submit()

      {:ok, _show_live_view, html} =
        live(conn, ~p"/brainstormings/#{brainstorming.id}/lanes/#{lane.id}/new_idea")

      assert html =~ "I am new"
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

  defp html_selector_idea_label_link(idea_label) do
    "a[data-testid=\"#{idea_label.id}\"][title=\"Label #{idea_label.name}\"]"
  end
end
