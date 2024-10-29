defmodule Mindwendel.Comments do
  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Comment

  require Logger

  @doc """
  Gets a single attached_file

  ## Examples

      iex> get_comment!("0323906b-b496-4778-ae67-1dd779d3de3c")
      %File{ ... }

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
  Deletes a comment.

  ## Examples

      iex> delete_comment(comment)
      {:ok, %Idea{}}

      iex> delete_comment(comment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end
end
