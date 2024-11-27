defmodule MindwendelWeb.IdeaLive.CardComponent do
  use MindwendelWeb, :live_component
  alias Mindwendel.Attachments
  alias Mindwendel.Ideas
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Likes

  @impl true
  def handle_event("delete_idea", %{"id" => id}, socket) do
    idea = Ideas.get_idea!(id)

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if has_moderating_or_ownership_permission(brainstorming, idea, current_user) do
      {:ok, _} = Ideas.delete_idea(idea)
    end

    # broadcast will take care of the removal from the list
    {:noreply, socket}
  end

  def handle_event("like", %{"id" => id}, socket) do
    Likes.add_like(id, socket.assigns.current_user.id)

    {:noreply, socket}
  end

  def handle_event("unlike", %{"id" => id}, socket) do
    Likes.delete_like(id, socket.assigns.current_user.id)

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

    IdeaLabels.remove_idea_label_from_idea(idea, idea_label)
    {:noreply, socket}
  end
end
