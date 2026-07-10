defmodule Mindwendel.Accounts.User do
  use Mindwendel.Schema

  import Ecto.Changeset

  alias Mindwendel.Accounts.BrainstormingModeratingUser
  alias Mindwendel.Accounts.BrainstormingUser
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea

  schema "users" do
    field :username, :string, default: "Anonymous"
    has_many :created_brainstormings, Brainstorming, foreign_key: :creating_user_id
    many_to_many :brainstormings, Brainstorming, join_through: BrainstormingUser

    many_to_many :moderated_brainstormings, Brainstorming,
      join_through: BrainstormingModeratingUser

    has_many :ideas, Idea

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username])
    |> default_anonymous_username()
    |> shorten_username()
    |> validate_required([:username])
    |> validate_length(:username, max: 50)
  end

  defp default_anonymous_username(changeset) do
    case get_change(changeset, :username) do
      nil ->
        changeset

      username when is_binary(username) ->
        if String.trim(username) == "" do
          put_change(changeset, :username, "Anonymous")
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp shorten_username(changeset) do
    if Map.has_key?(changeset.changes, :username),
      do: change(changeset, username: String.slice(changeset.changes.username, 0..49)),
      else: changeset
  end
end
