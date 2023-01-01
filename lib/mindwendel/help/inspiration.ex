defmodule Mindwendel.Help.Inspiration do
  @moduledoc false

  use Mindwendel.Schema

  import Ecto.Changeset

  schema "inspirations" do
    field :title, :string
    field :type, :string
    field :language, :string
    timestamps()
  end

  @doc false
  def changeset(technique, attrs) do
    technique
    |> cast(attrs, [:title, :type, :language])
    |> unique_constraint(:title)
  end
end
