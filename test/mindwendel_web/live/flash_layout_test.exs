defmodule MindwendelWeb.FlashLayoutTest do
  @moduledoc """
  Tests verifying flash message markup in layout templates.

  These tests cover:
  - Flash messages render with correct container structure
  - AutoDismissFlash hook is attached to flash elements
  - Close button (data-dismiss-flash) is present
  - data-flash-kind attribute is set correctly
  - Info and error flash kinds render the right alert classes

  Flash is triggered by LiveView server-side events that call put_flash/3,
  which is the natural way flash appears in this app's LiveView layout.
  """

  use MindwendelWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  import Mindwendel.BrainstormingsFixtures

  # Trigger an error flash by sending "generate_ai_ideas" as a non-moderating user.
  # The AI stub returns disabled so the permission check kicks in: non-moderating
  # users get "Permission denied" as an error flash.
  defp html_with_error_flash(conn, brainstorming) do
    {:ok, view, _html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

    render_click(view, "generate_ai_ideas", %{"id" => brainstorming.id})
    render(view)
  end

  # Trigger an info flash by sending "generate_ai_ideas" as a moderating user.
  # A moderating user gets "Generating ideas..." as info flash (AI disabled returns
  # quickly from the async handle_info).
  defp html_with_info_flash(conn, brainstorming, moderating_user) do
    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    render_click(view, "generate_ai_ideas", %{"id" => brainstorming.id})
    render(view)
  end

  describe "app.html.heex flash — error flash via LiveView event" do
    setup do
      # brainstorming_fixture creates a brainstorming with a moderating user.
      # The conn in tests uses a different anonymous session, so it's not a moderator.
      brainstorming = brainstorming_fixture()
      %{brainstorming: brainstorming}
    end

    test "renders flash-container wrapper when error flash is set", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      html = html_with_error_flash(conn, brainstorming)

      assert html =~ "flash-container"
    end

    test "error flash message text is rendered", %{conn: conn, brainstorming: brainstorming} do
      html = html_with_error_flash(conn, brainstorming)

      assert html =~ "Permission denied"
    end

    test "error flash element has AutoDismissFlash hook", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      html = html_with_error_flash(conn, brainstorming)

      assert html =~ ~r/phx-hook="AutoDismissFlash"/
    end

    test "error flash element has alert-danger class", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      html = html_with_error_flash(conn, brainstorming)

      assert html =~ "alert-danger"
    end

    test "error flash element has data-flash-kind attribute set to error", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      html = html_with_error_flash(conn, brainstorming)

      assert html =~ ~r/data-flash-kind="error"/
    end

    test "error flash element has a close button with data-dismiss-flash", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      html = html_with_error_flash(conn, brainstorming)

      assert html =~ ~r/data-dismiss-flash/
    end
  end

  describe "app.html.heex flash — info flash via LiveView event" do
    setup do
      brainstorming = brainstorming_fixture()
      # The moderating_user is the creating user who has admin rights
      moderating_user = List.first(brainstorming.moderating_users)
      %{brainstorming: brainstorming, moderating_user: moderating_user}
    end

    test "renders flash-container wrapper when info flash is set", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      html = html_with_info_flash(conn, brainstorming, moderating_user)

      assert html =~ "flash-container"
    end

    test "info flash message text is rendered", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      html = html_with_info_flash(conn, brainstorming, moderating_user)

      assert html =~ "Generating ideas..."
    end

    test "info flash element has AutoDismissFlash hook", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      html = html_with_info_flash(conn, brainstorming, moderating_user)

      assert html =~ ~r/phx-hook="AutoDismissFlash"/
    end

    test "info flash element has alert-info class", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      html = html_with_info_flash(conn, brainstorming, moderating_user)

      assert html =~ "alert-info"
    end

    test "info flash element has data-flash-kind attribute set to info", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      html = html_with_info_flash(conn, brainstorming, moderating_user)

      assert html =~ ~r/data-flash-kind="info"/
    end

    test "info flash element has a close button with data-dismiss-flash", %{
      conn: conn,
      brainstorming: brainstorming,
      moderating_user: moderating_user
    } do
      html = html_with_info_flash(conn, brainstorming, moderating_user)

      assert html =~ ~r/data-dismiss-flash/
    end
  end

  describe "app.html.heex flash — no flash" do
    setup do
      brainstorming = brainstorming_fixture()
      %{brainstorming: brainstorming}
    end

    test "does not render flash-container when no flash messages", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      {:ok, _view, html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

      refute html =~ ~r/class="[^"]*flash-container[^"]*"/
    end
  end
end
