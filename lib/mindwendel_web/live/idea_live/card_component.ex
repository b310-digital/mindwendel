defmodule MindwendelWeb.IdeaLive.CardComponent do
  use MindwendelWeb, :live_component
  alias Mindwendel.Attachments
  alias Mindwendel.Ideas
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Likes

  @impl true
  def handle_event("delete_idea", _params, socket) do
    idea = socket.assigns.idea

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if has_moderating_or_ownership_permission(brainstorming.id, idea, current_user) do
      {:ok, _} = Ideas.delete_idea(idea)
    end

    # broadcast will take care of the removal from the list
    {:noreply, socket}
  end

  def handle_event("like", _params, socket) do
    Likes.add_like(socket.assigns.idea.id, socket.assigns.current_user.id)

    {:noreply, socket}
  end

  def handle_event("unlike", _params, socket) do
    Likes.delete_like(socket.assigns.idea.id, socket.assigns.current_user.id)

    {:noreply, socket}
  end

  def handle_event(
        "add_idea_label_to_idea",
        %{
          "idea-label-id" => idea_label_id
        },
        socket
      ) do
    IdeaLabels.add_idea_label_to_idea(socket.assigns.idea, idea_label_id)
    {:noreply, socket}
  end

  def handle_event(
        "remove_idea_label_from_idea",
        %{
          "idea-label-id" => idea_label_id
        },
        socket
      ) do
    IdeaLabels.remove_idea_label_from_idea(socket.assigns.idea, idea_label_id)
    {:noreply, socket}
  end
end
