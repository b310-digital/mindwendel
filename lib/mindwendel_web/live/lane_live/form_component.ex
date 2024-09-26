defmodule MindwendelWeb.LaneLive.FormComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Lanes

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
    save_lane(socket, socket.assigns.action, lane_params)
  end

  defp save_lane(socket, :update, lane_params) do
    lane = Lanes.get_lane!(lane_params["id"])

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if current_user.id in [brainstorming.moderating_users |> Enum.map(& &1.id)] do
      case Lanes.update_lane(lane) do
        {:ok, _lane} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Lane created updated"))
           |> push_redirect(to: ~p"/brainstormings/#{brainstorming.id}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  defp save_lane(socket, :new, lane_params) do
    case Lanes.create_lane(lane_params) do
      {:ok, _lane} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Lane created successfully"))
         |> push_redirect(to: ~p"/brainstormings/#{socket.assigns.brainstorming.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
