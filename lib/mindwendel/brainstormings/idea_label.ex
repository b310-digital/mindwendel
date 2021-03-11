defmodule Mindwendel.Brainstormings.IdeaLabel do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming

  schema "idea_labels" do
    field :name, :string
    field :color, :string
    field :position_order, :integer

    belongs_to :brainstorming, Brainstorming, foreign_key: :brainstorming_id, type: :binary_id

    timestamps()
  end

  def changeset(idea_label, params \\ %{}) do
    idea_label
    |> cast(params, [:name, :color])
    |> validate_required([:name])
  end
end
