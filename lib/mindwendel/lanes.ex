defmodule Mindwendel.Lanes do
  @moduledoc """
  The Lanes context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Brainstormings.Lane
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
  Gets lanes for a brainstorming

  Raises `Ecto.NoResultsError` if the Lane does not exist.

  ## Examples

      iex> get_lanes_for_brainstorming(123)
      [%Lane{}, ...]

  """
  def get_lanes_for_brainstorming(id) do
    lane_query =
      from lane in Lane,
        where: lane.brainstorming_id == ^id

    Repo.all(lane_query)
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
  Creates a lane.

  ## Examples

      iex> create_lane(%{field: value})
      {:ok, %Lane{}}

      iex> create_lane(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_lane(attrs \\ %{}) do
    %Lane{}
    |> Lane.changeset(attrs)
    |> Repo.insert()
    |> Brainstormings.broadcast(:lane_created)
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
    lane
    |> Lane.changeset(attrs)
    |> Repo.update()
    |> Brainstormings.broadcast(:lane_updated)
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
end
