defmodule MindwendelWeb.LaneLive.FormComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Lanes

  @impl true
  def update(%{lane: lane} = assigns, socket) do
    changeset = Lanes.change_lane(lane)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"lane" => lane_params}, socket) do
    changeset =
      socket.assigns.lane
      |> Lanes.change_lane(lane_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"lane" => lane_params}, socket) do
    save_lane(socket, socket.assigns.action, lane_params)
  end

  defp save_lane(socket, :update, lane_params) do
    lane = Lanes.get_lane!(lane_params["id"])

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if current_user.id in [lane.user_id | brainstorming.moderating_users |> Enum.map(& &1.id)] do
      case Lanes.update_lane(
             lane,
             Map.put(lane_params, "user_id", lane.user_id || current_user.id)
           ) do
        {:ok, _lane} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Lane created updated"))
           |> push_redirect(to: socket.assigns.return_to)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, changeset: changeset)}
      end
    end
  end

  defp save_lane(socket, :new, lane_params) do
    Mindwendel.Accounts.update_user(socket.assigns.current_user, %{
      username: lane_params["username"]
    })

    case Lanes.create_lane(Map.put(lane_params, "user_id", socket.assigns.current_user.id)) do
      {:ok, _lane} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lane created successfully"))
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
