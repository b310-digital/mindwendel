defmodule Mindwendel.Brainstormings.Comment do
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
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:idea_id, :user_id, :comment_text, :username])
    |> validate_required([:idea_id, :comment_text, :username])
  end
end
