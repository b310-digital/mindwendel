defmodule MindwendelWeb.LaneLive.FormComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
        <:subtitle>Use this form to manage lane records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="lane-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <:actions>
          <.button phx-disable-with="Saving...">Save Lane</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{lane: lane} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Brainstormings.change_lane(lane))
     end)}
  end

  @impl true
  def handle_event("validate", %{"lane" => lane_params}, socket) do
    changeset = Brainstormings.change_lane(socket.assigns.lane, lane_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"lane" => lane_params}, socket) do
    save_lane(socket, socket.assigns.action, lane_params)
  end

  defp save_lane(socket, :edit, lane_params) do
    case Brainstormings.update_lane(socket.assigns.lane, lane_params) do
      {:ok, lane} ->
        notify_parent({:saved, lane})

        {:noreply,
         socket
         |> put_flash(:info, "Lane updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_lane(socket, :new, lane_params) do
    case Brainstormings.create_lane(lane_params) do
      {:ok, lane} ->
        notify_parent({:saved, lane})

        {:noreply,
         socket
         |> put_flash(:info, "Lane created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
