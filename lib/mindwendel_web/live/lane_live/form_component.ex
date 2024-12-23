defmodule MindwendelWeb.LaneLive.FormComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Lanes
  alias Mindwendel.Permissions

  @impl true
  def update(%{lane: lane} = assigns, socket) do
    changeset = Lanes.change_lane(lane)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"lane" => lane_params}, socket) do
    changeset =
      socket.assigns.lane
      |> Lanes.change_lane(lane_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save", %{"lane" => lane_params}, socket) do
    %{current_user: current_user, brainstorming_id: brainstorming_id} = socket.assigns

    if Permissions.has_moderating_permission(brainstorming_id, current_user) do
      save_lane(socket, socket.assigns.action, lane_params)
    else
      {:noreply, socket}
    end
  end

  defp save_lane(socket, :update, lane_params) do
    lane = Lanes.get_lane!(lane_params["id"])

    %{brainstorming_id: brainstorming_id} = socket.assigns

    case Lanes.update_lane(lane, lane_params) do
      {:ok, _lane} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lane updated"))
         |> push_event("submit-success", %{to: "#lane-modal"})
         |> push_navigate(to: ~p"/brainstormings/#{brainstorming_id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_lane(socket, :new, lane_params) do
    %{brainstorming_id: brainstorming_id} = socket.assigns

    case Lanes.create_lane(lane_params) do
      {:ok, _lane} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lane created successfully"))
         |> push_event("submit-success", %{to: "#lane-modal"})
         |> push_navigate(to: ~p"/brainstormings/#{brainstorming_id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
