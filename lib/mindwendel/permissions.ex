defmodule Mindwendel.Permissions do
  alias Mindwendel.Accounts.User

  @moduledoc """
  The Permissions context.
  """
  def has_moderating_permission(brainstorming_id, %User{} = current_user) do
    current_user.moderated_brainstormings
    |> Enum.map(& &1.id)
    |> Enum.member?(brainstorming_id)
  end

  def has_moderating_permission(_, _) do
    false
  end
end
