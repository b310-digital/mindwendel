defmodule MindwendelWeb.LiveHelpers do
  use Gettext, backend: MindwendelWeb.Gettext

  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.FeatureFlag

  def has_move_permission(brainstorming, current_user) do
    brainstorming.option_allow_manual_ordering or
      has_moderating_permission(brainstorming, current_user)
  end

  def has_moderating_permission(brainstorming, current_user) do
    Enum.member?(current_user.moderated_brainstormings |> Enum.map(& &1.id), brainstorming.id)
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

  def brainstormings_available_until() do
    Timex.Duration.from_days(
      Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]
    )
    |> Timex.format_duration(:humanized)
  end

  def show_idea_file_upload? do
    FeatureFlag.enabled?(:feature_file_upload)
  end

  def format_iso8601(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, date_time, _} -> Timex.from_now(date_time)
      {:error, _} -> iso8601
    end
  end

  def valid_stored_brainstorming?(brainstorming) do
    case Ecto.UUID.cast(brainstorming["id"]) do
      {:ok, _} -> brainstorming["last_accessed_at"] && brainstorming["name"]
      :error -> false
    end
  end
end
