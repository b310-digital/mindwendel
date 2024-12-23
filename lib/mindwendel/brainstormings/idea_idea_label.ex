defmodule Mindwendel.Brainstormings.IdeaIdeaLabel do
  # doesn't use `Mindwendel.Schema` as the default `@derive` there intereferes here
  use Ecto.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaLabel

  @primary_key false
  schema "idea_idea_labels" do
    belongs_to :idea, Idea, type: :binary_id, primary_key: true
    belongs_to :idea_label, IdeaLabel, type: :binary_id, primary_key: true

    timestamps()
  end

  @doc false
  def changeset(idea_idea_label, attrs \\ %{}) do
    idea_idea_label
    |> cast(attrs, [:idea_id, :idea_label_id])
    |> cast_assoc(:idea, required: true)
    |> cast_assoc(:idea_label, required: true)
    |> unique_constraint([:idea_id, :idea_label_id],
      name: :idea_idea_labels_idea_id_idea_label_id_index
    )
  end

  def bare_creation_changeset(idea_idea_label \\ %__MODULE__{}, attrs) do
    idea_idea_label
    |> cast(attrs, [:idea_id, :idea_label_id])
    |> validate_required([:idea_id, :idea_label_id])
    |> unique_constraint([:idea_id, :idea_label_id],
      name: :idea_idea_labels_idea_id_idea_label_id_index
    )
  end
end
