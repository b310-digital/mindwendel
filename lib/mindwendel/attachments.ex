defmodule Mindwendel.Attachments do
  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Attachments.File

  require Logger

  @doc """
  Gets a single attached_file

  Raises `Ecto.NoResultsError` if the Brainstorming does not exist.

  ## Examples

      iex> get_attached_file!("0323906b-b496-4778-ae67-1dd779d3de3c")
      %Brainstorming{ ... }

      iex> get_attached_file!("0323906b-b496-4778-ae67-1dd779d3de3c")
      ** (Ecto.NoResultsError)

      iex> get_attached_file!("not_a_valid_uuid_string")
      ** (Ecto.Query.CastError)

  """
  def get_attached_file!(id) do
    Repo.get!(File, id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking attached_file changes.

  ## Examples

      iex> change_attached_file(attached_file)
      %Ecto.Changeset(data: %File{})

  """
  def change_attached_file(%File{} = attached_file, attrs \\ %{}) do
    File.changeset(attached_file, attrs)
  end

  @doc """
  Deletes an attached_file

  ## Examples

      iex> delete_attached_file(attached_file)
      {:ok, %File{}}

      iex> delete_attached_file(attached_file)
      {:error, %Ecto.Changeset{}}

  """
  def delete_attached_file(%File{} = attached_file) do
    if attached_file.path do
      :ok = Mindwendel.Attachment.delete(attached_file.path)
    end

    Repo.delete(attached_file)
  end
end
