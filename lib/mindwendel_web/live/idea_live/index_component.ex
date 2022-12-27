defmodule MindwendelWeb.IdeaLive.IndexComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    idea = Brainstormings.get_idea!(id)

    {:noreply,
     socket
     |> push_patch(
       to: Routes.brainstorming_show_path(socket, :edit_idea, idea.brainstorming_id, id)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    idea = Brainstormings.get_idea!(id)

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if current_user.id in [idea.user_id | brainstorming.moderating_users |> Enum.map(& &1.id)] do
      {:ok, _} = Brainstormings.delete_idea(idea)
    end

    # broadcast will take care of the removal from the list
    {:noreply, socket}
  end

  @impl true
  def handle_event("like", %{"id" => id}, socket) do
    Brainstormings.add_like(id, socket.assigns.current_user.id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("unlike", %{"id" => id}, socket) do
    Brainstormings.delete_like(id, socket.assigns.current_user.id)

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
    idea = Brainstormings.get_idea!(idea_id)
    idea_label = Brainstormings.get_idea_label(idea_label_id)

    case(Brainstormings.add_idea_label_to_idea(idea, idea_label)) do
      {:ok, idea} ->
        {:noreply, socket}

      {:error, changeset} ->
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
    idea = Brainstormings.get_idea!(idea_id)
    idea_label = Brainstormings.get_idea_label(idea_label_id)

    case(Brainstormings.remove_idea_label_from_idea(idea, idea_label)) do
      {:ok, idea} ->
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, socket}
    end
  end
end
