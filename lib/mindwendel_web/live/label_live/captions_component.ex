defmodule MindwendelWeb.LabelLive.CaptionsComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings

  def handle_event("set_filter_idea_label", %{"id" => idea_label_id}, socket) do
    %{current_user: current_user, brainstorming: brainstorming, filtered_labels: filtered_labels} =
      socket.assigns

    if has_moderating_permission(brainstorming.id, current_user) do
      # If the filter is already present, remove it as its toggled. If not, add it.
      toggled_filters = build_filter_labels(filtered_labels, idea_label_id)

      # The brainstorming in the socket might be outdated in terms of
      # filter_labels_ids because we do not update the socket on every change.
      {:ok, refreshed_brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)

      Brainstormings.update_brainstorming(refreshed_brainstorming, %{
        filter_labels_ids: toggled_filters
      })
    end

    {:noreply, socket}
  end

  defp build_filter_labels(_filtered_labels, "filter-label-reset" = _idea_label_id) do
    []
  end

  defp build_filter_labels(filtered_labels, idea_label_id) do
    if Enum.member?(filtered_labels, idea_label_id),
      do:
        Enum.filter(filtered_labels, fn filter_id ->
          filter_id != idea_label_id
        end),
      else: [idea_label_id | filtered_labels]
  end
end
