defmodule MindwendelWeb.LaneLive.IndexComponent do
  require Logger
  use MindwendelWeb, :live_component

  alias Mindwendel.Ideas
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Likes
  alias Mindwendel.Lanes
  alias Mindwendel.Brainstormings

  @impl true
  def handle_event("delete_idea", %{"id" => id}, socket) do
    idea = Ideas.get_idea!(id)

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if current_user.id in [idea.user_id | brainstorming.moderating_users |> Enum.map(& &1.id)] do
      {:ok, _} = Ideas.delete_idea(idea)
    end

    # broadcast will take care of the removal from the list
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_lane", %{"id" => id}, socket) do
    lane = Lanes.get_lane!(id)

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if has_moderating_permission(brainstorming, current_user) do
      {:ok, _} = Lanes.delete_lane(lane)
    end

    # broadcast will take care of the removal from the list
    {:noreply, socket}
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    Likes.add_like(id, socket.assigns.current_user.id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("unlike", %{"id" => id}, socket) do
    Likes.delete_like(id, socket.assigns.current_user.id)

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
    brainstorming = Brainstormings.get_brainstorming!(brainstorming_id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_user_move(
        brainstorming_id,
        lane_id,
        id,
        new_position,
        old_position
      )

      Brainstormings.broadcast(
        {:ok, brainstorming},
        :brainstorming_updated
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

  def handle_event(
        "add_idea_label_to_idea",
        %{
          "idea-id" => idea_id,
          "idea-label-id" => idea_label_id
        },
        socket
      ) do
    idea = Ideas.get_idea!(idea_id)
    idea_label = IdeaLabels.get_idea_label(idea_label_id)

    case(IdeaLabels.add_idea_label_to_idea(idea, idea_label)) do
      {:ok, _idea} ->
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "remove_idea_label_from_idea",
        %{
          "idea-id" => idea_id,
          "idea-label-id" => idea_label_id
        },
        socket
      ) do
    idea = Ideas.get_idea!(idea_id)
    idea_label = IdeaLabels.get_idea_label(idea_label_id)

    case(IdeaLabels.remove_idea_label_from_idea(idea, idea_label)) do
      {:ok, _idea} ->
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("sort_by_likes", %{"id" => id, "lane-id" => lane_id}, socket) do
    brainstorming = Brainstormings.get_brainstorming!(id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_likes(id, lane_id)
    end

    {:noreply, socket}
  end

  def handle_event("sort_by_label", %{"id" => id, "lane-id" => lane_id}, socket) do
    brainstorming = Brainstormings.get_brainstorming!(id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_labels(id, lane_id)
    end

    {:noreply, socket}
  end
end
