defmodule Mindwendel.Brainstormings.Brainstorming do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Accounts.User
  alias Mindwendel.Accounts.BrainstormingUser

  schema "brainstormings" do
    field :name, :string
    field :admin_url_id, :binary_id
    has_many :ideas, Idea
    many_to_many :users, User, join_through: BrainstormingUser

    timestamps()
  end

  @doc false
  def changeset(brainstorming, attrs) do
    brainstorming
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> shorten_name
    |> gen_admin_url_id(brainstorming)
  end

  defp gen_admin_url_id(changeset, brainstorming) do
    if brainstorming.admin_url_id do
      changeset
    else
      change(changeset, admin_url_id: Ecto.UUID.generate())
    end
  end

  defp shorten_name(changeset) do
    if Map.has_key?(changeset.changes, :name),
      do: change(changeset, name: String.slice(changeset.changes.name, 0..200)),
      else: changeset
  end

  def changeset_update_users(brainstorming, users) do
    brainstorming
    |> change(%{})
    |> put_assoc(:users, users)
  end
end
