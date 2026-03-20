defmodule Mindwendel.Brainstormings.Comment do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Idea

  schema "idea_comments" do
    belongs_to :idea, Idea
    belongs_to :user, User
    field :body, :string, redact: true
    field :username, :string, default: "Anonymous", redact: true

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:idea_id, :user_id, :body, :username])
    |> validate_required([:idea_id, :body, :username])
    |> validate_length(:body, min: 1, max: 500)
    |> foreign_key_constraint(:idea_id, name: :idea_comments_idea_id_fkey)
  end
end
