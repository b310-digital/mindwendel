defmodule MindwendelWeb.IdeaLive.FormComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Ideas

  @impl true
  def update(%{idea: idea} = assigns, socket) do
    changeset = Ideas.change_idea(idea)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"idea" => idea_params}, socket) do
    changeset =
      socket.assigns.idea
      |> Ideas.change_idea(idea_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"idea" => idea_params}, socket) do
    save_idea(socket, socket.assigns.action, idea_params)
  end

  defp save_idea(socket, :update, idea_params) do
    idea = Ideas.get_idea!(idea_params["id"])

    %{current_user: current_user, brainstorming: brainstorming} = socket.assigns

    if current_user.id in [idea.user_id | brainstorming.moderating_users |> Enum.map(& &1.id)] do
      case Ideas.update_idea(
             idea,
             Map.put(idea_params, "user_id", idea.user_id || current_user.id)
           ) do
        {:ok, _idea} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Idea created updated"))
           |> push_redirect(to: socket.assigns.return_to)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, changeset: changeset)}
      end
    end
  end

  defp save_idea(socket, :new, idea_params) do
    Mindwendel.Accounts.update_user(socket.assigns.current_user, %{
      username: idea_params["username"]
    })

    case Ideas.create_idea(Map.put(idea_params, "user_id", socket.assigns.current_user.id)) do
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
