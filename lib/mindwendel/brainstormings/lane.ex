defmodule Mindwendel.Brainstormings.Lane do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Lanes
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
    |> validate_required([:brainstorming_id])
    |> add_position_order_if_missing()
  end

  defp add_position_order_if_missing(%Ecto.Changeset{changes: %{position_order: _}} = changeset) do
    changeset
  end

  defp add_position_order_if_missing(
         %Ecto.Changeset{
           data: %Mindwendel.Brainstormings.Lane{
             position_order: nil,
             brainstorming_id: brainstorming_id
           }
         } = changeset
       ) do
    changeset
    |> put_change(:position_order, generate_position_order(brainstorming_id))
  end

  defp add_position_order_if_missing(changeset) do
    changeset
  end

  defp generate_position_order(brainstorming_id) do
    max = Lanes.get_max_position_order(brainstorming_id)
    if max, do: max + 1, else: 1
  end
end
