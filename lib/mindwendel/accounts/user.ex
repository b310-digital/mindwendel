defmodule Mindwendel.Accounts.User do
  use Mindwendel.Schema

  import Ecto.Changeset

  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Accounts.BrainstormingUser

  schema "users" do
    field :username, :string, default: "Anonymous"
    many_to_many :brainstormings, Brainstorming, join_through: BrainstormingUser
    has_many :ideas, Idea

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> shorten_username
    |> validate_length(:username, max: 50)
  end

  defp shorten_username(changeset) do
    if Map.has_key?(changeset.changes, :username),
      do: change(changeset, username: String.slice(changeset.changes.username, 0..49)),
      else: changeset
  end
end
