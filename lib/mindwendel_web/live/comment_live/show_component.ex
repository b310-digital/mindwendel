defmodule MindwendelWeb.CommentLive.ShowComponent do
  use MindwendelWeb, :live_component
  alias Mindwendel.Comments

  @impl true
  def handle_event("edit_comment", _value, socket) do
    {:noreply, assign(socket, :live_action, :edit)}
  end

  def handle_event("delete_comment", _, socket) do
    %{comment: comment, idea: idea, current_user: current_user} = socket.assigns

    if comment.idea_id == idea.id and
         has_moderating_or_ownership_permission(idea.brainstorming_id, comment, current_user) do
      Comments.delete_comment(comment)
    end

    {:noreply, socket}
  end
end
