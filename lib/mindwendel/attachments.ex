defmodule Mindwendel.Attachments do
  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Attachment

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
    Repo.get!(Attachment, id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking attachment changes.

  ## Examples

      iex> change_attachment(attachment)
      %Ecto.Changeset(data: %Attachment{})

  """
  def change_attachment(%Attachment{} = attachment, attrs \\ %{}) do
    Attachment.changeset(attachment, attrs)
  end

  @doc """
  Deletes an attachment

  ## Examples

      iex> delete_attachment(attachment)
      {:ok, %Attachment{}}

      iex> delete_attachment(attachment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_attachment(%Attachment{} = attachment) do
    if attachment.path do
      :ok = Mindwendel.Attachment.delete(attachment.path)
    end

    Repo.delete(attachment)
  end
end
