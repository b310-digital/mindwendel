defmodule MindwendelWeb.LiveHelpers do
  use Gettext, backend: MindwendelWeb.Gettext

  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.FeatureFlag
  alias Mindwendel.Permissions

  def has_move_permission(brainstorming, current_user) do
    brainstorming.option_allow_manual_ordering or
      has_moderating_permission(brainstorming.id, current_user)
  end

  def has_moderating_permission(brainstorming_id, current_user) do
    Permissions.has_moderating_permission(brainstorming_id, current_user)
  end

  def has_ownership(record, current_user) do
    %{user_id: user_id} = record
    user_id == current_user.id
  end

  def has_moderating_or_ownership_permission(brainstorming_id, record, current_user) do
    has_ownership(record, current_user) or
      has_moderating_permission(brainstorming_id, current_user)
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

  def brainstormings_available_until() do
    Timex.Duration.from_days(
      Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]
    )
    |> Timex.format_duration(:humanized)
  end

  def show_idea_file_upload? do
    FeatureFlag.enabled?(:feature_file_upload)
  end
end
