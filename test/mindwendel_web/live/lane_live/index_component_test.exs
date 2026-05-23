defmodule MindwendelWeb.LaneLive.IndexComponentTest do
  use MindwendelWeb.ConnCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true
  import Phoenix.LiveViewTest

  alias Mindwendel.Accounts
  alias Mindwendel.Factory
  alias Mindwendel.Lanes

  setup %{conn: conn} do
    disable_ai()
    brainstorming = Factory.insert!(:brainstorming)
    moderating_user = Factory.insert!(:user)
    Accounts.add_moderating_user(brainstorming, moderating_user)
    lane = Enum.at(brainstorming.lanes, 0)

    %{
      brainstorming: brainstorming,
      moderating_user: moderating_user,
      conn: conn,
      lane: lane
    }
  end

  test "moderator can delete a lane from their own brainstorming", %{
    conn: conn,
    brainstorming: brainstorming,
    moderating_user: moderating_user,
    lane: lane
  } do
    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    view
    |> element("a[title='Delete lane']")
    |> render_click()

    assert Lanes.get_lane(lane.id) == nil
  end

  test "moderator cannot delete a lane from another brainstorming", %{
    conn: conn,
    brainstorming: brainstorming,
    moderating_user: moderating_user
  } do
    # Create a second brainstorming with its own lane
    other_brainstorming = Factory.insert!(:brainstorming)
    other_lane = Enum.at(other_brainstorming.lanes, 0)

    {:ok, view, _html} =
      conn
      |> init_test_session(%{current_user_id: moderating_user.id})
      |> live(~p"/brainstormings/#{brainstorming.id}")

    # Simulate a crafted event with a foreign lane ID targeting the LiveComponent
    view
    |> element("a[title='Delete lane']")
    |> render_click(%{"id" => other_lane.id})

    # The other lane must still exist
    assert Lanes.get_lane(other_lane.id) != nil
  end
end
