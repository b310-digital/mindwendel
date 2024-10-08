defmodule Mindwendel.Lanes do
  @moduledoc """
  The Lanes context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings

  require Logger

  @doc """
  Gets a single lane.

  Raises `Ecto.NoResultsError` if the Lane does not exist.

  ## Examples

      iex> get_lane!(123)
      %Lane{}

      iex> get_lane!(456)
      ** (Ecto.NoResultsError)

  """
  def get_lane!(id) do
    Repo.get!(Lane, id)
    |> Repo.preload(
      ideas: [
        :link,
        :likes,
        :label,
        :idea_labels
      ]
    )
  end

  @doc """
  Get max position order of lanes for a brainstorming

  ## Examples

      iex> get_max_position_order(123)
      1

  """
  def get_max_position_order(nil) do
    1
  end

  def get_max_position_order(brainstorming_id) do
    lane_query =
      from lane in Lane,
        where: lane.brainstorming_id == ^brainstorming_id and not is_nil(lane.position_order)

    Repo.aggregate(lane_query, :max, :position_order)
  end

  @doc """
  Gets lanes for a brainstorming with an optional filter, currently only filter_labels_ids is supported.

  Raises `Ecto.NoResultsError` if the Lane does not exist.

  ## Examples

      iex> get_lanes_for_brainstorming(123)
      [%Lane{}, ...]

  """
  def get_lanes_for_brainstorming(id, filters \\ %{}) do
    lane_query =
      from lane in Lane,
        where: lane.brainstorming_id == ^id,
        order_by: [
          asc: lane.position_order,
          asc: lane.inserted_at
        ]

    ideas_advanced_query = build_ideas_query_with_filter(filters)

    lane_query
    |> Repo.all()
    |> Repo.preload(
      ideas:
        ideas_advanced_query
        |> preload([
          :link,
          :likes,
          :idea_labels
        ])
    )
  end

  defp build_ideas_query_with_filter(%{filter_labels_ids: filter_labels_ids}) do
    from idea in Idea,
      left_join: labels in assoc(idea, :idea_labels),
      where: labels.id in ^filter_labels_ids
  end

  defp build_ideas_query_with_filter(%{} = _filters) do
    Idea
  end

  @doc """
  Creates a lane.

  ## Examples

      iex> create_lane(%{field: value})
      {:ok, %Lane{}}

      iex> create_lane(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_lane(attrs \\ %{}) do
    result =
      %Lane{}
      |> Lane.changeset(attrs)
      |> Repo.insert()
      |> Brainstormings.broadcast(:lane_created)

    result
  end

  @doc """
  Updates a lane.

  ## Examples

      iex> update_lane(lane, %{field: new_value})
      {:ok, %Lane{}}

      iex> update_lane(lane, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_lane(%Lane{} = lane, attrs) do
    update =
      lane
      |> Lane.changeset(attrs)
      |> Repo.update()

    broadcast_lanes_update(lane.brainstorming_id)
    update
  end

  @doc """
  Deletes a lane.

  ## Examples

      iex> delete_lane(lane)
      {:ok, %Lane{}}

      iex> delete_lane(lane)
      {:error, %Ecto.Changeset{}}

  """
  def delete_lane(%Lane{} = lane) do
    Repo.delete(lane) |> Brainstormings.broadcast(:lane_removed)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lane changes.

  ## Examples

      iex> change_lane(lane)
      %Ecto.Changeset{data: %Lane{}}

  """
  def change_lane(%Lane{} = lane, attrs \\ %{}) do
    Lane.changeset(lane, attrs)
  end

  def broadcast_lanes_update(brainstorming_id) do
    brainstorming = Brainstormings.get_brainstorming!(brainstorming_id)

    filter_label =
      if length(brainstorming.filter_labels_ids) > 0,
        do: %{filter_labels_ids: brainstorming.filter_labels_ids},
        else: %{}

    lanes = get_lanes_for_brainstorming(brainstorming_id, filter_label)
    Brainstormings.broadcast({:ok, brainstorming_id, lanes}, :lanes_updated)
  end
end
