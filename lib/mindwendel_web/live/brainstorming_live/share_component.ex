defmodule MindwendelWeb.BrainstormingLive.ShareComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Permissions

  def handle_event("toggle_url_secret", _value, socket) do
    %{
      brainstorming_id: brainstorming_id,
      uri: uri,
      admin_uri: admin_uri,
      current_user: current_user,
      activated_uri_type: activated_uri_type
    } = socket.assigns

    if Permissions.has_moderating_permission(brainstorming_id, current_user) do
      toggled_activated_uri = if activated_uri_type == :uri, do: :admin_uri, else: :uri
      active_uri = if toggled_activated_uri == :uri, do: uri, else: admin_uri

      {:noreply,
       socket
       |> assign(:activated_uri_type, toggled_activated_uri)
       |> assign(:active_uri, active_uri)}
    else
      {:noreply, socket}
    end
  end
end
