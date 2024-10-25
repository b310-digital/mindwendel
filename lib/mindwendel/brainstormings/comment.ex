defmodule Mindwendel.Brainstormings.Like do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Accounts.User

  schema "idea_comments" do
    belongs_to :idea, Idea
    belongs_to :user, User
    field :comment_text, :string
    field :username, :string, default: "Anonymous"

    timestamps()
  end

  @doc false
  def changeset(like, attrs) do
    like
    |> cast(attrs, [:idea_id, :user_id])
    |> validate_required([])
  end
end
