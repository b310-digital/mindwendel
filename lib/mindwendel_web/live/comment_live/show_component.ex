defmodule MindwendelWeb.CommentLive.ShowComponent do
  use MindwendelWeb, :live_component

  @impl true
  def update(
        %{comment: comment, brainstorming: brainstorming, current_user: current_user} = assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)}
  end
end
