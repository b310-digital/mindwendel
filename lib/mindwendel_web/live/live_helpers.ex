defmodule MindwendelWeb.LiveHelpers do
  import MindwendelWeb.Gettext

  alias Mindwendel.Brainstormings.Brainstorming

  def has_move_permission(brainstorming, current_user) do
    brainstorming.option_allow_manual_ordering or
      Enum.member?(brainstorming.moderating_users |> Enum.map(& &1.id), current_user.id)
  end

  def uuid do
    Ecto.UUID.generate()
  end

  def brainstorming_available_until_full_text(brainstorming) do
    gettext("Brainstorming will be deleted %{days}",
      days: Brainstorming.brainstorming_available_until(brainstorming)
    )
  end

  def brainstorming_available_until(brainstorming) do
    Brainstorming.brainstorming_available_until(brainstorming)
  end
end
