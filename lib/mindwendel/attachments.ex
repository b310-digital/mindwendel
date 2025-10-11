defmodule Mindwendel.Attachments do
  import Ecto.Query, warn: false
  alias Mindwendel.Attachments.File
  alias Mindwendel.Repo
  alias Mindwendel.Services.StorageService

  require Logger

  @doc """
  Gets a single attached_file

  ## Examples

      iex> get_attached_file("0323906b-b496-4778-ae67-1dd779d3de3c")
      %File{ ... }

  """
  def get_attached_file(id) do
    Repo.get(File, id)
  end

  @doc """
  Returns a simplified file type: image, pdf or misc

  ## Examples

      iex> simplified_attached_file_type("application/pdf")
      "pdf"

  """
  def simplified_attached_file_type(file_type) do
    case String.split(file_type || "", "/") do
      ["image", _] -> "image"
      [_, "pdf"] -> "pdf"
      [_, _] -> "misc"
      [_] -> "misc"
    end
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
      case StorageService.delete_file(attached_file.path) do
        {:ok} -> Repo.delete(attached_file)
        {:error, message} -> {:error, message}
      end
    end
  end
end
