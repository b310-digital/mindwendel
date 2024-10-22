defmodule Mindwendel.Attachments do
  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Attachments.File

  require Logger

  @doc """
  Gets a single attachment for an idea

  Raises `Ecto.NoResultsError` if the Brainstorming does not exist.

  ## Examples

      iex> get_attachment!("0323906b-b496-4778-ae67-1dd779d3de3c")
      %Brainstorming{ ... }

      iex> get_attachment!("0323906b-b496-4778-ae67-1dd779d3de3c")
      ** (Ecto.NoResultsError)

      iex> get_attachment!("not_a_valid_uuid_string")
      ** (Ecto.Query.CastError)

  """
  def get_attachment!(id) do
    Repo.get!(File, id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking attachment changes.

  ## Examples

      iex> change_attachment(attachment)
      %Ecto.Changeset(data: %File{})

  """
  def change_attachment(%File{} = attachment, attrs \\ %{}) do
    File.changeset(attachment, attrs)
  end

  @doc """
  Deletes an attachment

  ## Examples

      iex> delete_attachment(attachment)
      {:ok, %File{}}

      iex> delete_attachment(attachment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_attachment(%File{} = attachment) do
    if attachment.path do
      :ok = Mindwendel.Attachment.delete(attachment.path)
    end

    Repo.delete(attachment)
  end
end
