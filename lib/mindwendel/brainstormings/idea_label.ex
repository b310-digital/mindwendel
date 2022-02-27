defmodule Mindwendel.Brainstormings.IdeaLabel do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea

  schema "idea_labels" do
    field :name, :string
    field :color, :string
    field :position_order, :integer
    # See https://hexdocs.pm/ecto/Ecto.Changeset.html#module-the-on_replace-option
    field :delete, :boolean, virtual: true

    belongs_to :brainstorming, Brainstorming, foreign_key: :brainstorming_id, type: :binary_id

    has_many :ideas, Idea, foreign_key: :label_id
    timestamps()
  end

  def changeset(idea_label, params \\ %{})

  def changeset(idea_label, %{delete: true}) do
    %{Ecto.Changeset.change(idea_label, delete: true) | action: :delete}
    |> no_assoc_constraint(:ideas, message: "idea label associated with idea")
  end

  def changeset(idea_label, params) do
    idea_label
    |> cast(params, [:name, :color])
    |> validate_required([:name])
    |> validate_format(:color, ~r/^#[0-9a-f]{6}$/)
  end
end
