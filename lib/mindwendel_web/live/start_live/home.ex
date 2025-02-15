defmodule MindwendelWeb.StartLive.Home do
  use MindwendelWeb, :live_view

  import MindwendelWeb.LiveHelpers

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.LocalStorage

  @impl true
  def mount(_, session, socket) do
    current_user_id = Mindwendel.Services.SessionService.get_current_user_id(session)

    form =
      %Brainstorming{}
      |> Brainstormings.change_brainstorming(%{})
      |> Phoenix.Component.to_form()

    {:ok,
     socket
     |> assign(:current_user, Mindwendel.Accounts.get_user(current_user_id))
     |> assign(:form, form)
     |> assign(:brainstormings_stored, [])}
  end

  @impl true
  def handle_event("brainstormings_from_local_storage", brainstormings_stored, socket) do
    # Brainstormings are used from session data and local storage. Session data can be removed later and is only used for a transition period.
    valid_stored_brainstormings =
      LocalStorage.brainstormings_from_local_storage_and_session(
        brainstormings_stored,
        Brainstormings.list_brainstormings_for(
          get_in(socket.assigns, [Access.key(:current_user), Access.key(:id)])
        ),
        socket.assigns.current_user
      )

    {:noreply, assign(socket, :brainstormings_stored, valid_stored_brainstormings)}
  end
end
