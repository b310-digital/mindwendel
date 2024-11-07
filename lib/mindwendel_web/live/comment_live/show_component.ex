defmodule MindwendelWeb.CommentLive.ShowComponent do
  use MindwendelWeb, :live_component

  @impl true
  def handle_event("edit_comment", _value, socket) do
    {:noreply, assign(socket, :live_action, :edit)}
  end
end
