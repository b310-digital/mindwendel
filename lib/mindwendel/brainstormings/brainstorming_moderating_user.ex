defmodule Mindwendel.Brainstormings.BrainstormingModeratingUser do
  use Ecto.Schema
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Accounts.User

  @primary_key false
  schema "brainstorming_moderating_users" do
    belongs_to :brainstorming, Brainstorming, type: :binary_id
    belongs_to :user, User, type: :binary_id

    timestamps()
  end
end
