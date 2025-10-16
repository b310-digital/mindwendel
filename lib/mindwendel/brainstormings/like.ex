defmodule Mindwendel.Brainstormings.Like do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Idea

  schema "likes" do
    belongs_to :idea, Idea
    belongs_to :user, User

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
