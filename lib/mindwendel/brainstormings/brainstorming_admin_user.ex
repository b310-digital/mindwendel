defmodule Mindwendel.Brainstormings.BrainstormingAdminUser do
  use Ecto.Schema
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Accounts.User

  @primary_key false
  schema "brainstorming_admin_users" do
    belongs_to :brainstorming, Brainstorming, type: :binary_id
    belongs_to :user, User, type: :binary_id

    timestamps()
  end
end
