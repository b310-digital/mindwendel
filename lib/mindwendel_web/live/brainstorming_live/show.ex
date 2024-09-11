defmodule MindwendelWeb.BrainstormingLive.Show do
  use MindwendelWeb, :live_view

  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.Ideas
  alias Mindwendel.Brainstormings.Idea

  @impl true
  def mount(%{"id" => id}, session, socket) do
    if connected?(socket), do: Brainstormings.subscribe(id)

    current_user_id = Mindwendel.Services.SessionService.get_current_user_id(session)

    brainstorming =
      Brainstormings.get_brainstorming!(id)
      |> Accounts.merge_brainstorming_user(current_user_id)

    current_user = Mindwendel.Accounts.get_user(current_user_id)

    {
      :ok,
      socket
      |> assign(:brainstorming, brainstorming)
      |> assign(:current_user, current_user)
      |> assign(:inspiration, Mindwendel.Help.random_inspiration())
    }
  end

  def mount(%{"brainstorming_id" => brainstorming_id, "idea_id" => _idea_id}, session, socket) do
    mount(%{"id" => brainstorming_id}, session, socket)
  end

  def handle_params(
        %{"brainstorming_id" => brainstorming_id, "idea_id" => idea_id},
        uri,
        socket
      ) do
    {
      :noreply,
      socket
      |> assign(:ideas, Ideas.list_ideas_for_brainstorming(brainstorming_id))
      |> assign(:idea, Ideas.get_idea!(idea_id))
      |> assign(:uri, uri)
      |> apply_action(socket.assigns.live_action,
        brainstorming_id: brainstorming_id,
        idea_id: idea_id
      )
    }
  end

  @impl true
  def handle_params(%{"id" => id}, uri, socket) do
    {:noreply,
     socket
     |> assign(:ideas, Ideas.list_ideas_for_brainstorming(id))
     |> assign(:uri, uri)
     |> apply_action(socket.assigns.live_action, id)}
  end

  @impl true
  def handle_info({:idea_added, idea}, socket) do
    # uses the database to sort and update all ideas, instead of appending the idea to the end of list (which would be more performant)
    new_ideas = Ideas.list_ideas_for_brainstorming(idea.brainstorming_id)
    {:noreply, assign(socket, :ideas, new_ideas)}
  end

  @impl true
  def handle_info({:idea_removed, idea}, socket) do
    new_ideas = Enum.filter(socket.assigns.ideas, fn x -> x.id != idea.id end)
    {:noreply, assign(socket, :ideas, new_ideas)}
  end

  @impl true
  def handle_info({:brainstorming_updated, brainstorming}, socket) do
    {
      :noreply,
      socket
      |> assign(:brainstorming, Brainstormings.get_brainstorming!(brainstorming.id))
      |> assign(:ideas, Ideas.list_ideas_for_brainstorming(brainstorming.id))
    }
  end

  @impl true
  def handle_info({:idea_updated, idea}, socket) do
    # another option is to reload the ideas from the db - but this would trigger a new sorting which might confuse the user
    new_ideas = Enum.map(socket.assigns.ideas, fn e -> if e.id == idea.id, do: idea, else: e end)

    {:noreply, assign(socket, :ideas, new_ideas)}
  end

  defp apply_action(socket, :edit_idea, brainstorming_id: _brainstorming_id, idea_id: _idea_id) do
    socket
  end

  defp apply_action(socket, :new_idea, brainstorming_id) do
    socket
    |> assign(:page_title, gettext("%{name} - New Idea", name: socket.assigns.brainstorming.name))
    |> assign(:idea, %Idea{
      brainstorming_id: brainstorming_id,
      username: socket.assigns.current_user.username
    })
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, socket.assigns.brainstorming.name)
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, gettext("%{name} - Edit", name: socket.assigns.brainstorming.name))
  end

  defp apply_action(socket, :share, _params) do
    socket
    |> assign(:page_title, socket.assigns.brainstorming.name)
  end

  @impl true
  def handle_event("sort_by_likes", %{"id" => id}, socket) do
    brainstorming = Brainstormings.get_brainstorming!(id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_likes(id)
      Brainstormings.broadcast({:ok, brainstorming}, :brainstorming_updated)
    end

    {:noreply, socket}
  end

  def handle_event("sort_by_label", %{"id" => id}, socket) do
    brainstorming = Brainstormings.get_brainstorming!(id)

    if has_move_permission(brainstorming, socket.assigns.current_user) do
      Ideas.update_ideas_for_brainstorming_by_labels(id)
      Brainstormings.broadcast({:ok, brainstorming}, :brainstorming_updated)
    end

    {:noreply, socket}
  end

  def handle_event("handle_hotkey_i", _, socket) do
    if socket.assigns.live_action == :show do
      {:noreply,
       push_patch(socket,
         to: Routes.brainstorming_show_path(socket, :new_idea, socket.assigns.brainstorming)
       )}
    end
  end
end
