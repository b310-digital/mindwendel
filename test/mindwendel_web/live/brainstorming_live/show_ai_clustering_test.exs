defmodule MindwendelWeb.BrainstormingLiveAIClusteringTest do
  @moduledoc """
  LiveView integration tests covering the AI idea generation and clustering workflows.
  """

  use MindwendelWeb.ConnCase, async: false
  use Mindwendel.ChatCompletionsCase, async: false

  import Phoenix.LiveViewTest
  import Mindwendel.BrainstormingsFixtures
  import Ecto.Query

  alias Mindwendel.AI.Schemas.IdeaLabelAssignment
  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Ideas
  alias Mindwendel.Repo

  describe "AI idea clustering UX" do
    setup do
      brainstorming = brainstorming_fixture()
      {:ok, reloaded} = Brainstormings.get_brainstorming(brainstorming.id)
      [lane | _] = reloaded.lanes
      [label | _] = reloaded.labels

      {:ok, existing_idea} =
        Ideas.create_idea(%{
          username: "Existing",
          body: "Existing idea to cluster",
          brainstorming_id: reloaded.id,
          lane_id: lane.id
        })

      moderating_user = List.first(reloaded.users)
      Accounts.add_moderating_user(reloaded, moderating_user)

      %{
        brainstorming: reloaded,
        lane: lane,
        label: label,
        existing_idea: Repo.preload(existing_idea, :idea_labels),
        moderating_user: moderating_user
      }
    end

    test "cluster button labels existing and newly generated ideas", %{
      conn: conn,
      brainstorming: brainstorming,
      lane: lane,
      label: label,
      existing_idea: existing_idea,
      moderating_user: moderating_user
    } do
      generated_body = "AI generated idea"

      enable_ai()

      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> expect(:generate_ideas, fn title, _lanes, _existing_ideas, _locale ->
        {:ok, [%{"idea" => "#{title} - #{generated_body}", "lane_id" => lane.id}]}
      end)
      |> expect(:classify_labels, fn _title, _labels, idea_payload, _locale ->
        {:ok,
         Enum.map(idea_payload, fn idea_map ->
           %IdeaLabelAssignment{
             idea_id: idea_map.id,
             label_ids: [label.id]
           }
         end)}
      end)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view)

      click_html =
        view
        |> element("button[phx-click='generate_ai_ideas']")
        |> render_click()

      assert click_html =~ "Generating ideas..."

      :timer.sleep(200)

      html_after_generation = render(view)
      assert html_after_generation =~ generated_body

      refute has_element?(
               view,
               "div[data-testid='#{existing_idea.id}'] span.IndexComponent__IdeaLabelBadge[data-testid='#{label.id}']"
             )

      cluster_click_html =
        view
        |> element("button[phx-click='cluster_ai_ideas']")
        |> render_click()

      assert cluster_click_html =~ "Clustering ideas..."

      :timer.sleep(200)

      html_after_clustering = render(view)
      assert html_after_clustering =~ "Ideas clustered into labels"
      assert html_after_clustering =~ label.name

      assert has_element?(
               view,
               "div[data-testid='#{existing_idea.id}'] span.IndexComponent__IdeaLabelBadge[data-testid='#{label.id}']",
               label.name
             )

      new_idea =
        Repo.one!(
          from i in Idea,
            where:
              i.brainstorming_id == ^brainstorming.id and
                i.body == ^"#{brainstorming.name} - #{generated_body}"
        )

      assert has_element?(
               view,
               "div[data-testid='#{new_idea.id}'] span.IndexComponent__IdeaLabelBadge[data-testid='#{label.id}']",
               label.name
             )
    end

    test "shows warning flash when clustering fails", %{
      conn: conn,
      brainstorming: brainstorming,
      lane: lane,
      moderating_user: moderating_user
    } do
      enable_ai()

      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> expect(:generate_ideas, fn _title, _lanes, _existing_ideas, _locale ->
        {:ok, [%{"idea" => "Idea without label", "lane_id" => lane.id}]}
      end)
      |> expect(:classify_labels, fn _title, _labels, _idea_payload, _locale ->
        {:error, :invalid_response}
      end)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view)

      click_html =
        view
        |> element("button[phx-click='generate_ai_ideas']")
        |> render_click()

      assert click_html =~ "Generating ideas..."

      :timer.sleep(200)

      html_after_generation = render(view)
      assert html_after_generation =~ "Idea without label"
      refute html_after_generation =~ "AI clustering failed"

      cluster_click_html =
        view
        |> element("button[phx-click='cluster_ai_ideas']")
        |> render_click()

      assert cluster_click_html =~ "Clustering ideas..."

      :timer.sleep(200)

      html_after_clustering = render(view)
      assert html_after_clustering =~ "AI clustering failed"
    end
  end

  defp enable_ai do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> stub(:enabled?, fn -> true end)
  end

  defp allow_chat_completions(%Phoenix.LiveViewTest.View{pid: view_pid, proxy: proxy_pid}) do
    mock = Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock

    mock |> allow(self(), view_pid)

    if is_pid(proxy_pid) do
      mock |> allow(self(), proxy_pid)
    end
  end

  defp allow_chat_completions(pid) when is_pid(pid) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> allow(self(), pid)
  end
end
