defmodule Mindwendel.Brainstormings.Like do
  @moduledoc false

  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Accounts.User

  schema "likes" do
    belongs_to :idea, Idea, type: :binary_id
    belongs_to :user, User, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:idea_id, :user_id])
    |> validate_required([])
    |> unique_constraint([:idea_id, :user_id], name: :likes_idea_id_user_id_index)
  end
end
