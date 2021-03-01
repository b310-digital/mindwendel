defmodule MindwendelWeb.IdeaLive.FormComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings

  @impl true
  def update(%{idea: idea} = assigns, socket) do
    changeset = Brainstormings.change_idea(idea)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"idea" => idea_params}, socket) do
    changeset =
      socket.assigns.idea
      |> Brainstormings.change_idea(idea_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"idea" => idea_params}, socket) do
    save_idea(socket, socket.assigns.action, idea_params)
  end

  defp save_idea(socket, :new, idea_params) do
    Mindwendel.Accounts.update_user(socket.assigns.current_user, %{
      username: idea_params["username"]
    })

    case Brainstormings.create_idea(idea_params) do
      {:ok, _idea} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Idea created successfully"))
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
