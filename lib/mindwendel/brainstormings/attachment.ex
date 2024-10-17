defmodule Mindwendel.Brainstormings.Attachment do
  use Mindwendel.Schema
  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea

  schema "idea_attachments" do
    field :name, :string
    field :path, :string

    belongs_to :idea, Idea

    timestamps()
  end

  @doc false
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:path, :name])
    |> maybe_store_from_path_tmp(attrs)
  end

  defp maybe_store_from_path_tmp(changeset, attrs) do
    if attrs["path_tmp"] do
      changeset |> put_change(:path, attrs["path_tmp"])
    else
      changeset
    end
  end
end
