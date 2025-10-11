defmodule Mindwendel.IdeaLabels do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Lanes

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

  @doc """
  Replaces idea-label assignments for the provided set of ideas and broadcasts a lanes update once.
  """
  @spec replace_labels_for_brainstorming(
          binary(),
          list(%{idea_id: binary(), label_ids: [binary()]})
        ) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def replace_labels_for_brainstorming(_brainstorming_id, []), do: {:ok, 0}

  def replace_labels_for_brainstorming(brainstorming_id, assignments) do
    Repo.transaction(fn ->
      label_ids =
        Repo.all(
          from label in IdeaLabel,
            where: label.brainstorming_id == ^brainstorming_id,
            select: label.id
        )
        |> MapSet.new()

      idea_ids =
        Repo.all(
          from idea in Idea,
            where: idea.brainstorming_id == ^brainstorming_id,
            select: idea.id
        )
        |> MapSet.new()

      Enum.each(assignments, &process_assignment(&1, idea_ids, label_ids))

      :updated
    end)
    |> case do
      {:ok, :updated} ->
        Lanes.broadcast_lanes_update(brainstorming_id)
        {:ok, length(assignments)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_assignment(assignment, idea_ids, label_ids) do
    idea_id =
      assignment
      |> fetch_assignment_value(:idea_id)
      |> cast_uuid_or_rollback(:invalid_idea_id)

    unless MapSet.member?(idea_ids, idea_id) do
      Repo.rollback({:error, {:idea_not_found, idea_id}})
    end

    label_ids_for_idea =
      assignment
      |> fetch_assignment_value(:label_ids, [])
      |> normalize_label_ids()
      |> Enum.uniq()
      |> Enum.map(&validate_label_uuid(&1, label_ids))

    from(iil in IdeaIdeaLabel, where: iil.idea_id == ^idea_id)
    |> Repo.delete_all()

    Enum.each(label_ids_for_idea, &insert_label_assignment(idea_id, &1))
  end

  defp validate_label_uuid(label_id, label_ids) do
    label_uuid = cast_uuid_or_rollback(label_id, :invalid_label_id)

    unless MapSet.member?(label_ids, label_uuid) do
      Repo.rollback({:error, {:label_not_found, label_uuid}})
    end

    label_uuid
  end

  defp insert_label_assignment(idea_id, label_uuid) do
    %IdeaIdeaLabel{}
    |> IdeaIdeaLabel.bare_creation_changeset(%{
      idea_id: idea_id,
      idea_label_id: label_uuid
    })
    |> Repo.insert(on_conflict: :nothing)
    |> case do
      {:ok, _} ->
        :ok

      {:error, changeset} ->
        Repo.rollback({:error, changeset})
    end
  end

  defp fetch_assignment_value(assignment, key, default \\ nil) do
    Map.get(assignment, key, Map.get(assignment, to_string(key), default))
  end

  defp normalize_label_ids(nil), do: []
  defp normalize_label_ids(ids) when is_list(ids), do: ids
  defp normalize_label_ids(id), do: [id]

  defp cast_uuid_or_rollback(nil, error_reason) do
    Repo.rollback({:error, {error_reason, nil}})
  end

  defp cast_uuid_or_rollback(value, error_reason) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} ->
        uuid

      :error ->
        Repo.rollback({:error, {error_reason, value}})
    end
  end
end
