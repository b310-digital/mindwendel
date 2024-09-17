defmodule MindwendelWeb.LaneLive.Index do
  use MindwendelWeb, :live_view

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Lane

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :lanes, Brainstormings.list_lanes())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Lane")
    |> assign(:lane, Brainstormings.get_lane!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Lane")
    |> assign(:lane, %Lane{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Lanes")
    |> assign(:lane, nil)
  end

  @impl true
  def handle_info({MindwendelWeb.LaneLive.FormComponent, {:saved, lane}}, socket) do
    {:noreply, stream_insert(socket, :lanes, lane)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    lane = Brainstormings.get_lane!(id)
    {:ok, _} = Brainstormings.delete_lane(lane)

    {:noreply, stream_delete(socket, :lanes, lane)}
  end
end
