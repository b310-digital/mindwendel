defmodule MindwendelWeb.LaneLive.IndexComponent do
  require Logger
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings
  alias Mindwendel.Ideas
  alias Mindwendel.Lanes

  @impl true
  def handle_event("delete_lane", %{"id" => id}, socket) do
    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns
    lane = Lanes.get_lane(id, brainstorming.id)

    if lane && has_moderating_permission(lane.brainstorming_id, current_user) do
      {:ok, _} = Lanes.delete_lane(lane)
    end

    # broadcast will take care of the removal from the list
    {:noreply, socket}
  end

  def handle_event(
        "change_position",
        %{
          "id" => id,
          "lane_id" => lane_id,
          "new_position" => new_position,
          "old_position" => old_position
        },
        socket
      ) do
    # Always use the mounted brainstorming. The idea and the target lane are scoped to it
    # inside update_ideas_for_brainstorming_by_user_move/5.
    {:ok, brainstorming} = Brainstormings.get_brainstorming(socket.assigns.brainstorming.id)

    with true <- has_move_permission(brainstorming, socket.assigns.current_user),
         {:ok, _} <-
           Ideas.update_ideas_for_brainstorming_by_user_move(
             brainstorming.id,
             lane_id,
             id,
             new_position,
             old_position
           ) do
      {:noreply, socket}
    else
      # reset local move change
      _ -> {:noreply, socket |> assign(:brainstorming, brainstorming)}
    end
  end

  def handle_event(
        "change_position",
        params,
        socket
      ) do
    Logger.warning(
      "Handle event 'change_position', missing required params in #{inspect(params)}"
    )

    {:noreply, socket}
  end

  def handle_event("sort_by_likes", %{"id" => id, "lane-id" => lane_id}, socket) do
    {:ok, brainstorming} = Brainstormings.get_brainstorming(id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_likes(id, lane_id)
    end

    {:noreply, socket}
  end

  def handle_event("sort_by_label", %{"id" => id, "lane-id" => lane_id}, socket) do
    {:ok, brainstorming} = Brainstormings.get_brainstorming(id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_labels(id, lane_id)
    end

    {:noreply, socket}
  end
end
