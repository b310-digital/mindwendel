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

  def get_idea_label(id) when not is_nil(id) do
    Repo.get(IdeaLabel, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  def get_idea_label(id) when is_nil(id) do
    nil
  end

  def add_idea_label_to_idea(%Idea{} = idea, %IdeaLabel{} = idea_label) do
    idea = Repo.preload(idea, :idea_labels)

    idea_labels =
      (idea.idea_labels ++ [idea_label])
      |> Enum.map(&Ecto.Changeset.change/1)

    result =
      idea
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:idea_labels, idea_labels)
      |> Repo.update()

    Lanes.broadcast_lanes_update(idea.brainstorming_id)
    result
  end

  def remove_idea_label_from_idea(%Idea{} = idea, %IdeaLabel{} = idea_label) do
    from(idea_idea_label in IdeaIdeaLabel,
      where:
        idea_idea_label.idea_id == ^idea.id and
          idea_idea_label.idea_label_id == ^idea_label.id
    )
    |> Repo.delete_all()

    Lanes.broadcast_lanes_update(idea.brainstorming_id)
  end
end
