defmodule MindwendelWeb.StartLive.Home do
  use MindwendelWeb, :live_view

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming

  @impl true
  def mount(_, session, socket) do
    current_user =
      Mindwendel.Services.SessionService.get_current_user_id(session)
      |> Mindwendel.Accounts.get_user()

    form =
      %Brainstorming{}
      |> Brainstormings.change_brainstorming(%{})
      |> Phoenix.Component.to_form()

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:form, form)
     |> assign(:brainstormings_stored, [])}
  end

  @impl true
  def handle_event("brainstormings_from_local_storage", brainstormings_stored, socket) do
    {:noreply, assign(socket, :brainstormings_stored, brainstormings_stored)}
  end
end
