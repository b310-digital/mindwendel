defmodule Mindwendel.Brainstormings.Attachment do
  use Ecto.Schema
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
    |> validate_required([:path, :name])
  end
end
