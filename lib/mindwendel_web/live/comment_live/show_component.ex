defmodule MindwendelWeb.CommentLive.ShowComponent do
  use MindwendelWeb, :live_component
  alias Mindwendel.Comments

  @impl true
  def handle_event("edit_comment", _value, socket) do
    {:noreply, assign(socket, :live_action, :edit)}
  end

  @impl true
  def handle_event("delete_comment", _, socket) do
    Comments.delete_comment(socket.assigns.comment)

    {:noreply, socket}
  end
end
