defmodule Mindwendel.Help.BrainstormingTechnique do
  use Mindwendel.Schema

  import Ecto.Changeset

  schema "brainstorming_techniques" do
    field :title, :string
    field :description, :string
    timestamps()
  end

    @doc false
    def changeset(technique, attrs) do
      technique
      |> cast(attrs, [:title, :description, :language])
      |> unique_constraint(:title)
    end
end
