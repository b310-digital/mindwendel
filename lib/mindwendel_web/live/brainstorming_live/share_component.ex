defmodule MindwendelWeb.BrainstormingLive.ShareComponent do
  use MindwendelWeb, :live_component

  def handle_event("toggle_url_secret", _value, socket) do
    %{brainstorming: brainstorming, uri: uri, current_user: current_user} = socket.assigns

    if has_moderating_permission(brainstorming, current_user) do
      new_uri = create_download_link(brainstorming, uri)
      {:noreply, assign(socket, :uri, new_uri)}
    else
      {:noreply, socket}
    end
  end

  def secret_in_uri(uri) do
    uri |> String.split("#") |> length == 2
  end

  defp create_download_link(brainstorming, uri) do
    if secret_in_uri(uri) do
      url_fragments = String.split(uri, "#")
      List.first(url_fragments)
    else
      "#{uri}##{brainstorming.admin_url_id}"
    end
  end
end
