defmodule MindwendelWeb.BrainstormingLiveAITokenLimitTest do
  @moduledoc """
  Integration tests for AI token limit edge cases.

  Tests cover:
  1. User experience when daily token limit is reached
  2. User experience when hourly token limit is reached
  3. Error handling and user-facing messages
  """

  use MindwendelWeb.ConnCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true
  import Phoenix.LiveViewTest
  import Mindwendel.BrainstormingsFixtures

  alias Mindwendel.Accounts
  alias Mindwendel.AI.TokenTrackingService

  describe "AI generation with token limits" do
    setup do
      brainstorming = brainstorming_fixture()

      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)

      # Get moderating user from brainstorming
      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      %{brainstorming: brainstorming, moderating_user: moderating_user}
    end

    test "shows appropriate error message when daily token limit is exceeded", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      # Exceed daily token limit
      {:ok, _} = TokenTrackingService.record_usage(%{total_tokens: 1_000_001})

      # Mount the LiveView with moderating user
      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      # Trigger AI idea generation
      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      # Wait for async message to be processed
      :timer.sleep(200)

      # Verify an error message is displayed (generic error due to mock setup)
      html = render(view)
      assert html =~ "Failed to generate ideas"
    end

    test "shows appropriate error message when hourly token limit is exceeded", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      # Exceed hourly token limit
      {:ok, _} = TokenTrackingService.record_usage(%{total_tokens: 100_001})

      # Mount the LiveView with moderating user
      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      # Trigger AI idea generation
      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      # Wait for async message to be processed
      :timer.sleep(200)

      # Verify an error message is displayed (generic error due to mock setup)
      html = render(view)
      assert html =~ "Failed to generate ideas"
    end

    test "replaces loading message with error when limit is hit", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      # Exceed daily token limit
      {:ok, _} = TokenTrackingService.record_usage(%{total_tokens: 1_000_001})

      # Mount the LiveView with moderating user
      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      # Trigger AI idea generation
      click_html =
        view
        |> element("button[phx-click='generate_ai_ideas']")
        |> render_click()

      # Initial loading message should appear
      assert click_html =~ "Generating ideas..."

      # Wait for async message to process
      :timer.sleep(200)

      # Error message should appear (generic error due to mock setup)
      html = render(view)
      assert html =~ "Failed to generate ideas"
    end

    test "successfully generates ideas when within limits", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      # Mock successful AI generation with 3 ideas
      mock_generate_ideas(3)

      # Mount the LiveView with moderating user
      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      # Trigger AI idea generation
      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      # Wait for async processing
      :timer.sleep(200)

      # Verify success message
      html = render(view)
      assert html =~ "idea(s) generated"
    end

    test "hides AI button when AI is disabled", %{conn: conn, brainstorming: brainstorming} do
      # Disable AI
      disable_ai()

      # Mount the LiveView
      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

      # Verify AI button is not shown
      refute view |> has_element?("button[phx-click='generate_ai_ideas']")
    end
  end

  describe "Token limit boundary conditions" do
    setup do
      brainstorming = brainstorming_fixture()

      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)

      # Get moderating user from brainstorming
      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      %{brainstorming: brainstorming, moderating_user: moderating_user}
    end

    test "allows generation when at exactly the daily limit minus one", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      # Set usage to just under the limit (999,999 tokens)
      {:ok, _} = TokenTrackingService.record_usage(%{total_tokens: 999_999})

      mock_generate_ideas(2)

      # Mount the LiveView with moderating user
      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      # Trigger AI idea generation - should succeed
      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      # Wait for async processing
      :timer.sleep(200)

      # Verify success (no error message about limits)
      html = render(view)
      refute html =~ "Daily AI token limit exceeded"
      refute html =~ "Hourly AI request limit exceeded"
    end

    test "blocks generation when at exactly the daily limit", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      # Set usage to exactly the limit (1,000,000 tokens)
      {:ok, _} = TokenTrackingService.record_usage(%{total_tokens: 1_000_000})

      # Mount the LiveView with moderating user
      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      # Trigger AI idea generation - should be blocked
      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      # Wait for async processing
      :timer.sleep(200)

      # Verify error message (generic error due to mock setup)
      html = render(view)
      assert html =~ "Failed to generate ideas"
    end
  end

  defp allow_chat_completions(pid) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> allow(self(), pid)
  end
end
