defmodule MindwendelWeb.IdeaLive.IndexComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Ideas
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Likes
  alias Mindwendel.Brainstormings

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    idea = Ideas.get_idea!(id)

    {:noreply,
     socket
     |> push_patch(
       to: Routes.brainstorming_show_path(socket, :edit_idea, idea.brainstorming_id, id)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    idea = Ideas.get_idea!(id)

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if current_user.id in [idea.user_id | brainstorming.moderating_users |> Enum.map(& &1.id)] do
      {:ok, _} = Ideas.delete_idea(idea)
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
          "new_position" => new_position,
          "old_position" => old_position
        },
        socket
      ) do
    brainstorming = Brainstormings.get_brainstorming!(brainstorming_id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_user_move(
        brainstorming_id,
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
end
