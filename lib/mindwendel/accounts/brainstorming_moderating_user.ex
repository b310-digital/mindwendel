defmodule Mindwendel.Accounts.BrainstormingModeratingUser do
  # Not using Mindwendel.Schema as the `@derive` in there clashes here
  use Ecto.Schema
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Brainstorming

  @primary_key false
  schema "brainstorming_moderating_users" do
    belongs_to :brainstorming, Brainstorming, type: :binary_id
    belongs_to :user, User, type: :binary_id

    timestamps()
  end

  def changeset(%__MODULE__{} = brainstorming_moderating_user) do
    brainstorming_moderating_user
    |> Ecto.Changeset.cast(%{}, [:brainstorming_id, :user_id])
    |> Ecto.Changeset.validate_required([:brainstorming_id, :user_id])
    |> Ecto.Changeset.unique_constraint([:brainstorming_id, :user_id],
      name: :brainstorming_moderating_users_pkey
    )
  end
end
