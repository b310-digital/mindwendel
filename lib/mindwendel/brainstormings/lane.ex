defmodule Mindwendel.Brainstormings.Lane do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Brainstorming

  schema "lanes" do
    field :name, :string
    field :position_order, :integer
    belongs_to :brainstorming, Brainstorming, type: :binary_id
    has_many :ideas, Idea, preload_order: [asc: :position_order]

    timestamps()
  end

  @doc false
  def changeset(lane, attrs) do
    lane
    |> cast(attrs, [:name, :position_order, :brainstorming_id])
    |> validate_required([])
  end
end
