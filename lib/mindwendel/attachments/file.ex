defmodule Mindwendel.Attachments.File do
  use Mindwendel.Schema
  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.FeatureFlag
  alias Mindwendel.Services.StorageService
  require Logger

  schema "idea_files" do
    field :name, :string
    field :path, :string
    field :file_type, :string

    # Uploaded files are not deleted automatically. If an idea is deleted and an
    # attachment still present, the attachment db entry should remain available for
    # reference. It has to be deleted first.
    belongs_to :idea, Idea, on_replace: :raise

    timestamps()
  end

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:path, :name, :file_type])
    |> maybe_store_from_path_tmp()
  end

  defp maybe_store_from_path_tmp(changeset) do
    if FeatureFlag.enabled?(:feature_file_upload) and get_change(changeset, :path) do
      tmp_path = get_change(changeset, :path)
      object_filename = Path.basename(tmp_path)
      file_type = get_change(changeset, :file_type)

      # Store the file and handle both success and error cases
      result = StorageService.store_file(object_filename, tmp_path, file_type)

      # Always clean up the temporary file, regardless of storage outcome
      # This prevents temporary file accumulation even when storage fails
      cleanup_tmp_file(tmp_path)

      # Handle the storage result and update changeset accordingly
      handle_storage_result(changeset, result)
    else
      changeset
    end
  end

  # Handles successful storage by updating the path to the encrypted storage path
  defp handle_storage_result(changeset, {:ok, encrypted_file_path}) do
    put_change(changeset, :path, encrypted_file_path)
  end

  # Handles storage failures by adding a validation error to the changeset
  # This prevents Ecto from saving the record and provides user feedback
  defp handle_storage_result(changeset, {:error, reason}) do
    Logger.error("File storage failed: #{inspect(reason)}")
    add_error(changeset, :path, "failed to store file")
  end

  # Cleans up temporary file with robust error handling
  # This function ALWAYS attempts deletion and logs any issues
  defp cleanup_tmp_file(tmp_path) do
    case File.rm(tmp_path) do
      :ok ->
        # Successfully deleted, no action needed
        :ok

      {:error, :enoent} ->
        # File doesn't exist - this is acceptable (might have been already deleted)
        Logger.debug("Temporary file already removed: #{tmp_path}")
        :ok

      {:error, reason} ->
        # Deletion failed for other reasons - log but don't crash
        # This prevents blocking the user flow, but alerts ops to potential issues
        Logger.error("Failed to delete temporary file #{tmp_path}: #{inspect(reason)}")
        :ok
    end
  end
end
