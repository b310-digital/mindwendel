defmodule Mindwendel.Brainstormings.IdeaLabel do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaIdeaLabel

  schema "idea_labels" do
    field :name, :string
    field :color, :string
    field :position_order, :integer
    # See https://hexdocs.pm/ecto/Ecto.Changeset.html#module-the-on_replace-option
    field :delete, :boolean, virtual: true

    belongs_to :brainstorming, Brainstorming

    many_to_many :ideas, Idea, join_through: "idea_idea_labels", on_replace: :delete
    has_many :idea_idea_labels, IdeaIdeaLabel, on_replace: :delete

    timestamps()
  end

  def changeset(idea_label, params) do
    idea_label
    |> cast(params, [:name, :color])
    |> validate_required([:name])
    |> validate_format(:color, ~r/^#[0-9a-f]{6}$/)
    |> foreign_key_constraint(:ideas,
      name: "idea_idea_labels_idea_label_id_fkey",
      message: "idea label associated with idea"
    )
    |> no_assoc_constraint(:idea_idea_labels, message: "idea label associated with idea")
  end
end
