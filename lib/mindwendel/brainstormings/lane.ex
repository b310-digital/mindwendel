defmodule Mindwendel.Brainstormings.Lane do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Lanes

  schema "lanes" do
    field :name, :string
    field :position_order, :integer
    belongs_to :brainstorming, Brainstorming
    has_many :ideas, Idea, preload_order: [asc: :position_order, asc: :inserted_at]

    timestamps()
  end

  @doc """
  Changeset for creating a lane. Only on creation the brainstorming of a lane is set.
  """
  def create_changeset(lane, attrs) do
    lane
    |> cast(attrs, [:brainstorming_id])
    |> changeset(attrs)
  end

  @doc """
  Changeset for updating a lane. The brainstorming of an existing lane cannot be changed.
  """
  def changeset(lane, attrs) do
    lane
    |> cast(attrs, [:name, :position_order])
    |> validate_required([:brainstorming_id])
    |> add_position_order_if_missing()
  end

  defp add_position_order_if_missing(%Ecto.Changeset{changes: %{position_order: _}} = changeset) do
    changeset
  end

  defp add_position_order_if_missing(
         %Ecto.Changeset{
           changes: %{
             name: _,
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
