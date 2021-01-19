defmodule Mindwendel.Accounts.User do
  use Mindwendel.Schema

  import Ecto.Changeset

  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Accounts.BrainstormingUser

  schema "users" do
    field :username, :string, default: "Anonym"
    many_to_many :brainstormings, Brainstorming, join_through: BrainstormingUser

    timestamps()
  end

  def changeset(user, attrs) do
    user |> cast(attrs, [:username])
  end
end
