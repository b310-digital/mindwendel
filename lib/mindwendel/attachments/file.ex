defmodule Mindwendel.Attachments.File do
  use Mindwendel.Schema
  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.FeatureFlag
  alias Mindwendel.Services.StorageService

  schema "idea_files" do
    field :name, :string
    field :path, :string
    field :file_type, :string

    # Uploaded files are not deleted automatically, therefore if an idea is deleted and an attachment still present, the attachment db entry should still be available for reference. It has to be deleted first.
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
      object_filename = Path.basename(get_change(changeset, :path))

      {:ok, encrypted_file_path} =
        StorageService.store_file(
          object_filename,
          get_change(changeset, :path),
          get_change(changeset, :file_type)
        )

      # clear old tmp file
      File.rm(get_change(changeset, :path))
      changeset |> put_change(:path, encrypted_file_path)
    else
      changeset
    end
  end
end
