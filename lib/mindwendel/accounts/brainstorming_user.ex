defmodule Mindwendel.Accounts.BrainstormingUser do
  use Mindwendel.Schema
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Brainstorming

  schema "brainstorming_users" do
    belongs_to :brainstorming, Brainstorming
    belongs_to :user, User

    timestamps()
  end
end
