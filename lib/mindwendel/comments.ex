defmodule Mindwendel.Comments do
  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Comment
  alias Mindwendel.Brainstormings
  alias Mindwendel.Ideas

  require Logger

  @doc """
  Gets a single comment

  ## Examples

      iex> get_comment!("0323906b-b496-4778-ae67-1dd779d3de3c")
      %Comment{ ... }

  """
  def get_comment!(id) do
    Repo.get!(Comment, id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.

  ## Examples

      iex> change_comment(comment)
      %Ecto.Changeset(data: %Comment{})

  """
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.changeset(comment, attrs)
  end

  @doc """
  Creates a comment.

  ## Examples

      iex> create_comment(%{field: value})
      {:ok, %Comment{}}

      iex> create_comment(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_comment(attrs \\ %{}) do
    result =
      %Comment{}
      |> Comment.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, comment} -> Ideas.increment_comment_count(comment.idea_id)
      {:error, _} -> nil
    end

    handle_result_for_broadcast(result)
    result
  end

  @doc """
  Updates a comment.

  ## Examples

      iex> update_comment(comment, %{field: new_value})
      {:ok, %Comment{}}

      iex> update_comment(comment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_comment(%Comment{} = comment, attrs) do
    result =
      comment
      |> Comment.changeset(attrs)
      |> Repo.update()

    handle_result_for_broadcast(result)
    result
  end

  @doc """
  Deletes a comment.

  ## Examples

      iex> delete_comment(comment)
      {:ok, %Comment{}}

      iex> delete_comment(comment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_comment(%Comment{} = comment) do
    result = Repo.delete(comment)

    case result do
      {:ok, comment} -> Ideas.decrement_comment_count(comment.idea_id)
    end

    handle_result_for_broadcast(result)
    result
  end

  defp handle_result_for_broadcast(result) do
    case result do
      {:ok, comment} ->
        idea =
          Ideas.get_idea!(comment.idea_id)
          |> Brainstormings.preload_idea_for_broadcast()

        Brainstormings.broadcast(
          {:ok, idea},
          :idea_updated
        )

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
