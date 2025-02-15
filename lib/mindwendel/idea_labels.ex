defmodule Mindwendel.IdeaLabels do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Lanes
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.IdeaIdeaLabel

  require Logger

  def get_idea_labels(ids) do
    filtered_ids = Enum.filter(ids, fn id -> !is_nil(id) end)
    Repo.all(from label in IdeaLabel, where: label.id in ^filtered_ids)
  end

  def get_idea_label(id) when not is_nil(id) do
    Repo.get(IdeaLabel, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  def get_idea_label(id) when is_nil(id) do
    nil
  end

  # As the broadcast results in a full reload of the ideas, we don't need to actually update
  # the idea struct, a new association is enough
  def add_idea_label_to_idea(idea, idea_label_id) do
    result =
      %{idea_id: idea.id, idea_label_id: idea_label_id}
      |> IdeaIdeaLabel.bare_creation_changeset()
      |> Repo.insert()

    Lanes.broadcast_lanes_update(idea.brainstorming_id)
    result
  end

  def remove_idea_label_from_idea(%Idea{} = idea, idea_label_id) do
    result =
      from(idea_idea_label in IdeaIdeaLabel,
        where:
          idea_idea_label.idea_id == ^idea.id and
            idea_idea_label.idea_label_id == ^idea_label_id
      )
      |> Repo.delete_all()

    Lanes.broadcast_lanes_update(idea.brainstorming_id)
    result
  end
end
