defmodule MindwendelWeb.BrainstormingLive.Show do
  use MindwendelWeb, :live_view

  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.Lanes
  alias Mindwendel.Ideas
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.LocalStorage

  @impl true
  def mount(%{"id" => id}, session, socket) do
    if connected?(socket), do: Brainstormings.subscribe(id)

    # If the admin secret in the URL after the hash (only available inside the client session) is given, add the user as moderating user to the brainstorming.
    # If not, add the user as normal user.
    current_user_id = Mindwendel.Services.SessionService.get_current_user_id(session)

    case Brainstormings.get_brainstorming(id) do
      {:ok, brainstorming} ->
        Brainstormings.update_last_accessed_at(brainstorming)
        admin_secret = get_connect_params(socket)["adminSecret"]

        if Brainstormings.validate_admin_secret(brainstorming, admin_secret) do
          Accounts.add_moderating_user(brainstorming, current_user_id)
        end

        Accounts.merge_brainstorming_user(brainstorming, current_user_id)

        lanes = Lanes.get_lanes_for_brainstorming_with_labels_filtered(id)
        # load the user, also for permissions of brainstormings
        current_user = Mindwendel.Accounts.get_user(current_user_id)

        {
          :ok,
          socket
          |> assign(:brainstormings_stored, [])
          |> assign(:current_view, socket.view)
          |> assign(:brainstorming, brainstorming)
          |> assign(:lanes, lanes)
          |> assign(:filtered_labels, brainstorming.filter_labels_ids)
          |> assign(:current_user, current_user)
          |> assign(:inspiration, Mindwendel.Help.random_inspiration())
        }

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:missing_brainstorming_id, id)
         |> put_flash(:error, gettext("Brainstorming not found"))
         |> redirect(to: "/")}
    end
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
  def handle_event("brainstormings_from_local_storage", brainstormings_stored, socket) do
    # Brainstormings are used from session data and local storage. Session data can be removed later and is only used for a transition period.
    valid_stored_brainstormings =
      LocalStorage.brainstormings_from_local_storage_and_session(
        brainstormings_stored,
        Brainstormings.list_brainstormings_for(socket.assigns.current_user.id),
        socket.assigns.current_user
      )

    {:noreply, assign(socket, :brainstormings_stored, valid_stored_brainstormings)}
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

  def handle_info({:lane_updated, lane}, socket) do
    new_lanes =
      Enum.map(socket.assigns.lanes, fn existing_lane ->
        if lane.id == existing_lane.id, do: lane, else: existing_lane
      end)

    {:noreply, assign(socket, :lanes, new_lanes)}
  end

  def handle_info({:idea_updated, idea}, socket) do
    # first, update the specific card of the idea
    send_update(MindwendelWeb.IdeaLive.CardComponent, id: idea.id, idea: idea)
    # if the idea show modal is opened, also update the idea within the modal
    if socket.assigns.live_action == :show_idea and socket.assigns.idea.id == idea.id do
      send_update(MindwendelWeb.IdeaLive.ShowComponent, id: :show, idea: idea)
    end

    {:noreply, socket}
  end

  def handle_info({:brainstorming_filter_updated, filtered_labels, lanes}, socket) do
    {:noreply,
     socket
     |> assign(:filtered_labels, filtered_labels)
     |> assign(:lanes, lanes)}
  end

  def handle_info({:brainstorming_updated, brainstorming}, socket) do
    # the backdrop of the bootstrap modal gets sometimes stuck on the pages as its out of reach for the component
    # therefore we patch the url to reload it

    {:noreply,
     socket
     |> assign(:brainstorming, brainstorming)}
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
         :show_idea,
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
