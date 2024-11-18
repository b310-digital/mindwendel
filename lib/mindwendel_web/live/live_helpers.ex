defmodule MindwendelWeb.LiveHelpers do
  use Gettext, backend: MindwendelWeb.Gettext

  alias Mindwendel.Brainstormings.Brainstorming

  def has_move_permission(brainstorming, current_user) do
    brainstorming.option_allow_manual_ordering or
      has_moderating_permission(brainstorming, current_user)
  end

  def has_moderating_permission(brainstorming, current_user) do
    IO.inspect Enum.member?(brainstorming.moderating_users |> Enum.map(& &1.id), current_user.id)
    Enum.member?(brainstorming.moderating_users |> Enum.map(& &1.id), current_user.id)
  end

  def has_ownership(record, current_user) do
    %{user_id: user_id} = record
    user_id == current_user.id
  end

  def has_moderating_or_ownership_permission(brainstorming, record, current_user) do
    has_ownership(record, current_user) or has_moderating_permission(brainstorming, current_user)
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

  def show_idea_file_upload do
    Application.fetch_env!(:mindwendel, :options)[:feature_file_upload]
  end
end
