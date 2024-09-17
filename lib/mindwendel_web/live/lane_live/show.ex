defmodule MindwendelWeb.LaneLive.Show do
  use MindwendelWeb, :live_view

  alias Mindwendel.Brainstormings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:lane, Brainstormings.get_lane!(id))}
  end

  defp page_title(:show), do: "Show Lane"
  defp page_title(:edit), do: "Edit Lane"
end
