defmodule Mindwendel.Likes do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Ideas
  alias Mindwendel.Lanes
  alias Mindwendel.Brainstormings.Like

  require Logger

  @doc """
  Returns a Boolean if a like for the given idea and user exists.

  ## Examples

      iex> exists_like_for_idea?(1, 2)
      true

  """
  def exists_like_for_idea?(idea_id, user_id) do
    Repo.exists?(from like in Like, where: like.user_id == ^user_id and like.idea_id == ^idea_id)
  end

  @doc """
  Returns a broadcast tuple of the idea update.

  ## Examples

      iex> add_like(1, 2)
      {:ok, %Idea{}}

  """
  def add_like(idea_id, user_id) do
    {status, result} =
      %Like{}
      |> Like.changeset(%{idea_id: idea_id, user_id: user_id})
      |> Repo.insert()

    case status do
      :ok ->
        {:ok, Lanes.broadcast_lanes_update(Ideas.get_idea!(idea_id).brainstorming_id)}

      :error ->
        {:error, result}
    end
  end

  @doc """
  Deletes a like for an idea by a given user

  ## Examples

      iex> delete_like(1, 2)
      {:ok, %Idea{}}

  """
  def delete_like(idea_id, user_id) do
    # we ignore the result, delete_all returns the count of deleted items. We'll reload and broadcast the idea either way:
    Repo.delete_all(
      from like in Like, where: like.user_id == ^user_id and like.idea_id == ^idea_id
    )

    Lanes.broadcast_lanes_update(Ideas.get_idea!(idea_id).brainstorming_id)
  end

  @doc """
  Count likes for an idea.

  ## Examples

      iex> count_likes_for_idea(idea)
      5

  """
  def count_likes_for_idea(idea), do: idea |> Ecto.assoc(:likes) |> Repo.aggregate(:count, :id)
end
