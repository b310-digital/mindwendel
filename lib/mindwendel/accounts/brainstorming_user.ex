defmodule Mindwendel.Accounts.BrainstormingUser do
  @moduledoc false

  use Mindwendel.Schema
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Accounts.User

  schema "brainstorming_users" do
    belongs_to :brainstorming, Brainstorming, foreign_key: :brainstorming_id, type: :binary_id
    belongs_to :user, User, foreign_key: :user_id, type: :binary_id

    timestamps()
  end
end
