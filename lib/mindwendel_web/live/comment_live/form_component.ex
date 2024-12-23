defmodule MindwendelWeb.CommentLive.FormComponent do
  use MindwendelWeb, :live_component
  alias Mindwendel.Comments
  alias Mindwendel.Brainstormings.Comment

  @impl true
  def update(
        %{comment: comment} =
          assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Comments.change_comment(comment))
     end)}
  end

  def update(
        %{idea: idea, current_user: current_user} = assigns,
        socket
      ) do
    comment = %Comment{
      idea_id: idea.id,
      username: current_user.username
    }

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:comment, fn -> comment end)
     |> assign_new(:form, fn ->
       to_form(Comments.change_comment(comment))
     end)}
  end

  @impl true
  def handle_event("close", _, socket) do
    # The close button is either pressed inside the comment component, where a comment might be edited, or inside the "new comment" form.
    # Depending on the location, either patch back to the brainstorming or simply change back to view mode inside the comment.
    %{brainstorming_id: brainstorming_id, comment: comment} = socket.assigns

    case socket.assigns.action do
      :new ->
        {:noreply,
         push_patch(
           socket,
           to: "/brainstormings/#{brainstorming_id}"
         )}

      :update ->
        send_update(MindwendelWeb.CommentLive.ShowComponent, id: comment.id, live_action: :show)
        {:noreply, socket}
    end
  end

  def handle_event("validate", %{"comment" => comment_params}, socket) do
    changeset = Comments.change_comment(socket.assigns.comment, comment_params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"comment" => comment_params}, socket) do
    save_comment(socket, socket.assigns.action, comment_params)
  end

  defp save_comment(socket, :update, comment_params) do
    %{current_user: current_user, comment: comment, brainstorming_id: brainstorming_id} =
      socket.assigns

    if has_moderating_or_ownership_permission(brainstorming_id, comment, current_user) do
      comment_params_merged =
        comment_params
        |> Map.put("user_id", comment.user_id || current_user.id)
        |> Map.put("idea_id", socket.assigns.idea.id)

      case Comments.update_comment(
             comment,
             comment_params_merged
           ) do
        {:ok, _comment} ->
          {:noreply,
           socket
           |> put_flash(:info, gettext("Comment updated"))}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      {:noreply, assign(socket, form: to_form(Comments.change_comment(comment)))}
    end
  end

  defp save_comment(socket, :new, comment_params) do
    comment_params_merged =
      comment_params
      |> Map.put("user_id", socket.assigns.current_user.id)
      |> Map.put("idea_id", socket.assigns.idea.id)

    case Comments.create_comment(comment_params_merged) do
      {:ok, _comment} ->
        # reset the form
        new_comment = %Comment{
          idea_id: socket.assigns.idea.id,
          username: socket.assigns.current_user.username
        }

        {:noreply,
         socket
         |> assign(comment: new_comment)
         |> assign(form: to_form(Comments.change_comment(new_comment)))
         |> put_flash(:info, gettext("Comment created successfully"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
