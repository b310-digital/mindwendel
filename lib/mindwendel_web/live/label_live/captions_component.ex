defmodule MindwendelWeb.LabelLive.CaptionsComponent do
  use MindwendelWeb, :live_component

  alias Mindwendel.Brainstormings

  def handle_event("set_filter_idea_label", %{"id" => idea_label_id}, socket) do
    brainstorming = socket.assigns.brainstorming
    current_user = socket.assigns.current_user

    if has_moderating_permission(brainstorming, current_user) do
      # If the filter is already present, remove it as its toggled. If not, add it.
      toggled_filters = build_filter_labels(brainstorming, idea_label_id)
      Brainstormings.update_brainstorming(brainstorming, %{filter_labels_ids: toggled_filters})
    end

    {:noreply, socket}
  end

  defp build_filter_labels(_brainstorming, "filter-label-reset" = _idea_label_id) do
    []
  end

  defp build_filter_labels(brainstorming, idea_label_id) do
    if Enum.member?(brainstorming.filter_labels_ids, idea_label_id),
      do:
        Enum.filter(brainstorming.filter_labels_ids, fn filter_id ->
          filter_id != idea_label_id
        end),
      else: [idea_label_id | brainstorming.filter_labels_ids]
  end
end
