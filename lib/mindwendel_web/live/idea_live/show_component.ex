defmodule MindwendelWeb.IdeaLive.ShowComponent do
  use MindwendelWeb, :live_component

  @impl true
  def update(
        %{idea: idea, brainstorming: brainstorming, current_user: current_user} = assigns,
        socket
      ) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  @impl true
  def update(
        %{idea: idea} = assigns,
        socket
      ) do
    IO.inspect(idea)

    {:ok,
     socket
     |> assign(assigns)}
  end
end
