defmodule MindwendelWeb.LaneLive.IndexComponent do
  require Logger
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings
  alias Mindwendel.Ideas
  alias Mindwendel.Lanes

  @impl true
  def handle_event("delete_lane", %{"id" => id}, socket) do
    lane = Lanes.get_lane!(id)

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if has_moderating_permission(brainstorming.id, current_user) do
      {:ok, _} = Lanes.delete_lane(lane)
    end

    # broadcast will take care of the removal from the list
    {:noreply, socket}
  end

  def handle_event(
        "change_position",
        %{
          "id" => id,
          "brainstorming_id" => brainstorming_id,
          "lane_id" => lane_id,
          "new_position" => new_position,
          "old_position" => old_position
        },
        socket
      ) do
    {:ok, brainstorming} = Brainstormings.get_brainstorming(brainstorming_id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_user_move(
        brainstorming_id,
        lane_id,
        id,
        new_position,
        old_position
      )

      {:noreply, socket}
    else
      # reset local move change
      {:noreply, socket |> assign(:brainstorming, brainstorming)}
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
