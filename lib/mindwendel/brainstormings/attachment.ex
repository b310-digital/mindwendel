defmodule Mindwendel.Brainstormings.Attachment do
  use Mindwendel.Schema
  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea

  schema "idea_attachments" do
    field :name, :string
    field :path, :string

    # Uploaded files are not deleted automatically, therefore if an idea is deleted and an attachment still present, the attachment db entry should still be available for reference. It has to be deleted first.
    belongs_to :idea, Idea, on_replace: :raise

    timestamps()
  end

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:path, :name])
    |> maybe_store_from_path_tmp(attrs)
  end

  defp maybe_store_from_path_tmp(changeset, attrs) do
    if attrs["path"] do
      {:ok, final_path} = Mindwendel.Attachment.store(attrs["path"])
      changeset |> put_change(:path, final_path)
    else
      changeset
    end
  end
end
