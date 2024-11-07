defmodule MindwendelWeb.IdeaLive.ShowComponent do
  use MindwendelWeb, :live_component

  @impl true
  def update(
        %{idea: idea, brainstorming: brainstorming, current_user: current_user} = assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  @impl true
  def update(
        %{idea: idea} = assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  def handle_info({:idea_updated, idea}, socket) do
    # For the time being, we ignore idea updates as this results in modal problems.
    # Idea updates are mostly triggered due to new comments
    {:noreply, socket}
  end
end
