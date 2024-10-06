defmodule MindwendelWeb.BrainstormingLive.Show do
  use MindwendelWeb, :live_view

  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.Lanes
  alias Mindwendel.Ideas
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Lane

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
      |> assign(:lanes, brainstorming.lanes)
      |> assign(:current_user, current_user)
      |> assign(:inspiration, Mindwendel.Help.random_inspiration())
    }
  end

  def mount(%{"brainstorming_id" => brainstorming_id, "idea_id" => _idea_id}, session, socket) do
    mount(%{"id" => brainstorming_id}, session, socket)
  end

  def mount(%{"brainstorming_id" => brainstorming_id, "lane_id" => _lane_id}, session, socket) do
    mount(%{"id" => brainstorming_id}, session, socket)
  end

  def mount(%{"id" => id, "lane_id" => _lane_id}, session, socket) do
    mount(%{"id" => id}, session, socket)
  end

  @impl true
  def handle_params(
        params,
        _uri,
        socket
      ) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({:lane_created, lane}, socket) do
    lanes = socket.assigns.lanes ++ [lane]
    {:noreply, assign(socket, :lanes, lanes)}
  end

  def handle_info({:lane_removed, lane}, socket) do
    lanes = Enum.filter(socket.assigns.lanes, fn existing_lane -> existing_lane.id != lane.id end)
    {:noreply, assign(socket, :lanes, lanes)}
  end

  def handle_info({:lanes_updated, lanes}, socket) do
    {:noreply, assign(socket, :lanes, lanes)}
  end

  def handle_info({:brainstorming_updated, brainstorming}, socket) do
    # the backdrop of the bootstrap modal gets sometimes stuck on the pages as its out of reach for the component
    # therefore we patch the url to reload it
    {:noreply,
     push_patch(assign(socket, :brainstorming, brainstorming),
       to: "/brainstormings/#{brainstorming.id}"
     )}
  end

  def handle_info({:user_updated, user}, socket) do
    {:noreply, assign(socket, :current_user, user)}
  end

  defp apply_action(
         socket,
         :edit_idea,
         %{"brainstorming_id" => _brainstorming_id, "idea_id" => idea_id}
       ) do
    socket
    |> assign(:idea, Ideas.get_idea!(idea_id))
  end

  defp apply_action(
         socket,
         :edit_lane,
         %{"brainstorming_id" => _brainstorming_id, "lane_id" => lane_id}
       ) do
    socket
    |> assign(:lane, Lanes.get_lane!(lane_id))
  end

  defp apply_action(socket, :new_idea, %{"id" => id, "lane_id" => lane_id}) do
    socket
    |> assign(:page_title, gettext("%{name} - New Idea", name: socket.assigns.brainstorming.name))
    |> assign(:idea, %Idea{
      brainstorming_id: id,
      lane_id: lane_id,
      username: socket.assigns.current_user.username
    })
  end

  defp apply_action(socket, :new_lane, %{"id" => brainstorming_id}) do
    socket
    |> assign(:page_title, gettext("%{name} - New Lane", name: socket.assigns.brainstorming.name))
    |> assign(:lane, %Lane{
      brainstorming_id: brainstorming_id
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
end
