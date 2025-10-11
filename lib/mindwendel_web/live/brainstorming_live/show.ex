defmodule MindwendelWeb.BrainstormingLive.Show do
  use MindwendelWeb, :live_view

  require Logger

  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Ideas
  alias Mindwendel.Lanes
  alias Mindwendel.LocalStorage
  alias Mindwendel.Services.IdeaClusteringService
  alias Mindwendel.Services.IdeaService
  alias Mindwendel.Services.SessionService
  alias MindwendelWeb.IdeaLive.CardComponent
  alias MindwendelWeb.IdeaLive.ShowComponent

  @impl true
  def mount(%{"id" => id}, session, socket) do
    if connected?(socket), do: Brainstormings.subscribe(id)

    # If the admin secret in the URL after the hash (only available inside the client
    # session) is given, add the user as moderating user to the brainstorming.
    # If not, add the user as normal user.
    current_user_id = SessionService.get_current_user_id(session)

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
        current_user = Accounts.get_user(current_user_id)

        {
          :ok,
          socket
          |> assign(:brainstormings_stored, [])
          |> assign(:current_view, socket.view)
          |> assign(:brainstorming, brainstorming)
          |> assign(:lanes, lanes)
          |> assign(:filtered_labels, brainstorming.filter_labels_ids)
          |> assign(:current_user, current_user)
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
    # Brainstormings are used from session data and local storage. Session data can be
    # removed later and is only used for a transition period.
    valid_stored_brainstormings =
      LocalStorage.brainstormings_from_local_storage_and_session(
        brainstormings_stored,
        Brainstormings.list_brainstormings_for(socket.assigns.current_user.id),
        socket.assigns.current_user
      )

    {:noreply, assign(socket, :brainstormings_stored, valid_stored_brainstormings)}
  end

  def handle_event("generate_ai_ideas", %{"id" => id}, socket) do
    # Send async message to self to perform the AI generation
    # This allows us to show the loading message immediately and return control to the UI
    # Note: HTTP timeout is configured via MW_AI_REQUEST_TIMEOUT (default: 60s)
    # If the request times out, handle_info will replace this flash with an error message
    if has_moderating_permission(id, socket.assigns.current_user) do
      send(self(), {:do_generate_ai_ideas, id})
      {:noreply, put_flash(socket, :info, gettext("Generating ideas..."))}
    else
      {:noreply, put_flash(socket, :error, gettext("Permission denied"))}
    end
  end

  def handle_event("cluster_ai_ideas", %{"id" => id}, socket) do
    cond do
      not ai_clustering_enabled?() ->
        {:noreply, put_flash(socket, :error, gettext("AI clustering is disabled"))}

      not has_moderating_permission(id, socket.assigns.current_user) ->
        {:noreply, put_flash(socket, :error, gettext("Permission denied"))}

      true ->
        send(self(), {:do_cluster_ai_ideas, id})
        {:noreply, put_flash(socket, :info, gettext("Clustering ideas..."))}
    end
  end

  def handle_event("handle_hotkey_i", _, socket) do
    if socket.assigns.live_action == :show do
      case socket.assigns.lanes do
        [first_lane | _] ->
          {:noreply,
           push_patch(socket,
             to:
               ~p"/brainstormings/#{socket.assigns.brainstorming}/lanes/#{first_lane.id}/new_idea"
           )}

        [] ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
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
    send_update(CardComponent, id: idea.id, idea: idea)
    # if the idea show modal is opened, also update the idea within the modal
    if socket.assigns.live_action == :show_idea and socket.assigns.idea.id == idea.id do
      send_update(ShowComponent, id: :show, idea: idea)
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
    # The backdrop of the bootstrap modal sometimes gets stuck on the page because
    # it is out of reach for the component. Patch the URL to reload it.

    {:noreply,
     socket
     |> assign(:brainstorming, brainstorming)}
  end

  def handle_info({:user_updated, user}, socket) do
    {:noreply, assign(socket, :current_user, user)}
  end

  def handle_info({:do_generate_ai_ideas, id}, socket) do
    if has_moderating_permission(id, socket.assigns.current_user) do
      do_generate_ai_ideas(id, socket)
    else
      {:noreply, put_flash(socket, :error, gettext("Permission denied"))}
    end
  end

  def handle_info({:do_cluster_ai_ideas, id}, socket) do
    cond do
      not has_moderating_permission(id, socket.assigns.current_user) ->
        {:noreply, put_flash(socket, :error, gettext("Permission denied"))}

      not ai_clustering_enabled?() ->
        {:noreply, put_flash(socket, :error, gettext("AI clustering is disabled"))}

      true ->
        do_cluster_ai_ideas(id, socket)
    end
  end

  defp do_generate_ai_ideas(id, socket) do
    with {:ok, brainstorming} <- Brainstormings.get_brainstorming(id),
         brainstorming <- Mindwendel.Repo.preload(brainstorming, :lanes),
         result <- IdeaService.add_ideas_to_brainstorming(brainstorming) do
      handle_ai_generation_result(result, id, socket)
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Brainstorming not found"))}
    end
  end

  defp do_cluster_ai_ideas(id, socket) do
    with {:ok, brainstorming} <- Brainstormings.get_brainstorming(id),
         result <- IdeaClusteringService.cluster_labels(brainstorming) do
      handle_ai_clustering_result(result, id, socket)
    else
      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Brainstorming not found"))}
    end
  end

  defp handle_ai_generation_result({:ok, ideas}, id, socket) do
    lanes = Lanes.get_lanes_for_brainstorming_with_labels_filtered(id)

    socket =
      socket
      |> assign(:lanes, lanes)
      |> put_generation_flash(ideas)

    {:noreply, socket}
  end

  defp handle_ai_generation_result({:error, :daily_limit_exceeded}, _id, socket) do
    Logger.warning("AI request blocked: daily token limit exceeded")

    {:noreply,
     put_flash(
       socket,
       :error,
       gettext("Daily AI token limit exceeded. Please try again tomorrow.")
     )}
  end

  defp handle_ai_generation_result({:error, :hourly_limit_exceeded}, _id, socket) do
    Logger.warning("AI request blocked: hourly token limit exceeded")

    {:noreply,
     put_flash(
       socket,
       :error,
       gettext("Hourly AI request limit exceeded. Please try again later.")
     )}
  end

  defp handle_ai_generation_result({:error, reason}, _id, socket) do
    Logger.error("AI idea generation failed: #{inspect(reason)}")
    {:noreply, put_flash(socket, :error, gettext("Failed to generate ideas"))}
  end

  defp put_generation_flash(socket, []),
    do: put_flash(socket, :error, gettext("No ideas generated"))

  defp put_generation_flash(socket, ideas) do
    put_flash(
      socket,
      :info,
      gettext("%{length} idea(s) generated", %{length: length(ideas)})
    )
  end

  defp handle_ai_clustering_result({:ok, assignments} = result, id, socket)
       when is_list(assignments) do
    lanes = Lanes.get_lanes_for_brainstorming_with_labels_filtered(id)

    socket =
      socket
      |> assign(:lanes, lanes)
      |> maybe_assign_updated_brainstorming(id)
      |> put_clustering_flash(result)

    {:noreply, socket}
  end

  defp handle_ai_clustering_result({:ok, :skipped} = result, id, socket) do
    lanes = Lanes.get_lanes_for_brainstorming_with_labels_filtered(id)

    socket =
      socket
      |> assign(:lanes, lanes)
      |> maybe_assign_updated_brainstorming(id)
      |> put_clustering_flash(result)

    {:noreply, socket}
  end

  defp handle_ai_clustering_result({:error, _reason} = result, _id, socket) do
    {:noreply, put_clustering_flash(socket, result)}
  end

  defp put_clustering_flash(socket, {:ok, assignments}) when is_list(assignments) do
    if assignments == [] do
      put_flash(socket, :info, gettext("No new clustering changes"))
    else
      put_flash(socket, :info, gettext("Ideas clustered into labels"))
    end
  end

  defp put_clustering_flash(socket, {:ok, :skipped}) do
    put_flash(socket, :info, gettext("Nothing to cluster right now"))
  end

  defp put_clustering_flash(socket, {:error, _reason}) do
    put_flash(socket, :error, gettext("AI clustering failed"))
  end

  defp maybe_assign_updated_brainstorming(socket, id) do
    case Brainstormings.get_brainstorming(id) do
      {:ok, brainstorming} ->
        assign(socket, :brainstorming, brainstorming)

      {:error, reason} ->
        Logger.warning(
          "Failed to refresh brainstorming #{id} after AI clustering: #{inspect(reason)}"
        )

        socket
    end
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
