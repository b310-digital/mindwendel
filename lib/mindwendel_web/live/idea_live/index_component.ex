defmodule MindwendelWeb.IdeaLive.IndexComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    idea = Brainstormings.get_idea!(id)

    if socket.assigns.current_user.id == idea.user_id do
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

  def handle_event("update_label", %{"id" => id, "label-id" => label_id}, socket) do
    idea_label = Brainstormings.get_idea_label(label_id)

    Brainstormings.get_idea!(id)
    |> Brainstormings.update_idea_label(idea_label)

    {:noreply, socket}
  end

  def handle_event(
        "add_idea_label",
        %{"idea-id" => idea_id, "idea-label-id" => idea_label_id},
        socket
      ) do
    idea = Brainstormings.get_idea!(idea_id)
    idea_label = Brainstormings.get_idea_label(idea_label_id)

    # TODO: Convert to set
    idea_labels_new =
      [idea_label | idea.idea_labels]
      |> IO.inspect()
      |> Enum.map(&Map.from_struct/1)
      |> IO.inspect()

    case(Brainstormings.update_idea(idea, %{idea_labels: idea_labels_new})) do
      {:ok, idea} ->
        IO.inspect("ok")
        {:noreply, socket}

      {:error, changeset} ->
        IO.inspect("error")
        {:noreply, socket}
    end
  end

  def handle_event("remove_idea_label", %{"id" => id, "label-id" => label_id}, socket) do
    {:noreply, socket}
  end

  def handle_event("update_label", %{"id" => id}, socket) do
    handle_event("update_label", %{"id" => id, "label-id" => nil}, socket)
  end
end
