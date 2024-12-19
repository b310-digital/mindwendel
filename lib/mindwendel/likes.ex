defmodule Mindwendel.Likes do
  @moduledoc """
  The Likes context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Ideas
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Like

  require Logger

  @doc """
  Returns a boolean if like with a given user id exists in the given likes.
  This method is primarily used with preloaded data from an idea, therefore it is not needed to reload data from the repo.

  ## Examples

      iex> exists_user_in_likes?([...], 2)
      true

  """
  def exists_user_in_likes?(likes, user_id) do
    likes |> Enum.map(fn like -> like.user_id end) |> Enum.member?(user_id)
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
        {:ok, Brainstormings.broadcast({:ok, Ideas.get_idea!(idea_id)}, :idea_updated)}

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

    Brainstormings.broadcast({:ok, Ideas.get_idea!(idea_id)}, :idea_updated)
  end

  @doc """
  Count likes for an idea.

  ## Examples

      iex> count_likes_for_idea(idea)
      5

  """
  def count_likes_for_idea(idea), do: idea |> Ecto.assoc(:likes) |> Repo.aggregate(:count, :id)
end
