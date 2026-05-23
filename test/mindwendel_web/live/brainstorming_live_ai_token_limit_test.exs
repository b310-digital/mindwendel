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
      mock_generate_ideas_error(:daily_limit_exceeded)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Daily AI token limit exceeded"
    end

    test "shows appropriate error message when hourly token limit is exceeded", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      mock_generate_ideas_error(:hourly_limit_exceeded)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Hourly AI request limit exceeded"
    end

    test "replaces loading message with error when limit is hit", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      mock_generate_ideas_error(:daily_limit_exceeded)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      click_html =
        view
        |> element("button[phx-click='generate_ai_ideas']")
        |> render_click()

      # Initial loading message should appear
      assert click_html =~ "Generating ideas..."

      # Wait for async message to process
      :timer.sleep(200)

      # Error message should appear
      html = render(view)
      assert html =~ "Daily AI token limit exceeded"
    end

    test "successfully generates ideas when within limits", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      mock_generate_ideas(3)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      :timer.sleep(200)

      html = render(view)
      assert html =~ "idea(s) generated"
    end

    test "hides AI button when AI is disabled", %{conn: conn, brainstorming: brainstorming} do
      disable_ai()

      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

      refute view |> has_element?("button[phx-click='generate_ai_ideas']")
    end
  end

  describe "Token limit boundary conditions" do
    setup do
      brainstorming = brainstorming_fixture()

      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)

      moderating_user = List.first(brainstorming.users)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      %{brainstorming: brainstorming, moderating_user: moderating_user}
    end

    test "allows generation when within limits", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      mock_generate_ideas(2)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      :timer.sleep(200)

      html = render(view)
      refute html =~ "Daily AI token limit exceeded"
      refute html =~ "Hourly AI request limit exceeded"
    end

    test "blocks generation when daily limit is reached", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      mock_generate_ideas_error(:daily_limit_exceeded)

      {:ok, view, _html} =
        conn
        |> init_test_session(%{current_user_id: moderating_user.id})
        |> live(~p"/brainstormings/#{brainstorming.id}")

      allow_chat_completions(view.pid)

      view |> element("button[phx-click='generate_ai_ideas']") |> render_click()

      :timer.sleep(200)

      html = render(view)
      assert html =~ "Daily AI token limit exceeded"
    end
  end

  defp allow_chat_completions(pid) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> allow(self(), pid)
  end
end
