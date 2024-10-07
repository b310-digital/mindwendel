defmodule Mindwendel.Accounts.BrainstormingUser do
  use Mindwendel.Schema
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Accounts.User

  schema "brainstorming_users" do
    belongs_to :brainstorming, Brainstorming
    belongs_to :user, User

    timestamps()
  end
end
