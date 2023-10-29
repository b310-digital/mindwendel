defmodule Mindwendel.Attachments.Link do
  @moduledoc false

  use Mindwendel.Schema
  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea

  schema "links" do
    field :url, :string
    field :title, :string
    field :description, :string
    field :img_preview_url, :string
    belongs_to :idea, Idea, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:url, :desciption, :title, :img_preview_url, :idea_id])
    |> validate_required([:url, :idea_id])
  end
end
