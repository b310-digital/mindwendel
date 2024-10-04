defmodule MindwendelWeb.IdeaLive.FormComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Ideas

  @impl true
  def update(%{idea: idea} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Ideas.change_idea(idea))
     end)}
  end

  @impl true
  def handle_event("validate", %{"idea" => idea_params}, socket) do
    changeset = Ideas.change_idea(socket.assigns.idea, idea_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
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
           |> push_event("submit-success", %{to: "#idea-modal"})
           |> put_flash(:info, gettext("Idea updated"))
           |> push_patch(to: ~p"/brainstormings/#{brainstorming.id}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  defp save_idea(socket, :new, idea_params) do
    case Ideas.create_idea(Map.put(idea_params, "user_id", socket.assigns.current_user.id)) do
      {:ok, _idea} ->
        {:ok, user} =
          Mindwendel.Accounts.update_user(socket.assigns.current_user, %{
            username: idea_params["username"]
          })

        send(self(), {:user_updated, user})

        {:noreply,
         socket
         |> push_event("submit-success", %{to: "#idea-modal"})
         |> put_flash(:info, gettext("Idea created successfully"))
         |> push_patch(to: ~p"/brainstormings/#{idea_params["brainstorming_id"]}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
