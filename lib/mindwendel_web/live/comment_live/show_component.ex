defmodule MindwendelWeb.CommentLive.ShowComponent do
  use MindwendelWeb, :live_component
  alias Mindwendel.Comments

  @impl true
  def handle_event("edit_comment", _value, socket) do
    {:noreply, assign(socket, :live_action, :edit)}
  end

  def handle_event("delete_comment", _, socket) do
    %{brainstorming_id: brainstorming_id, comment: comment, current_user: current_user} =
      socket.assigns

    if has_moderating_or_ownership_permission(brainstorming_id, comment, current_user) do
      Comments.delete_comment(socket.assigns.comment)
    end

    {:noreply, socket}
  end
end
