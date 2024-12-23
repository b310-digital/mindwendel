defmodule Mindwendel.Permissions do
  @moduledoc """
  The Permissions context.
  """
  def has_moderating_permission(brainstorming_id, current_user) when current_user != nil do
    Enum.member?(current_user.moderated_brainstormings |> Enum.map(& &1.id), brainstorming_id)
  end

  def has_moderating_permission(_, _) do
    false
  end
end
