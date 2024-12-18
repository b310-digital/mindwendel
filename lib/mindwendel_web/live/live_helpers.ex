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

  def format_iso8601(iso8601) when iso8601 != nil do
    case DateTime.from_iso8601(iso8601) do
      {:ok, date_time, _} -> date_time
      {:error, _} -> nil
    end
  end

  def format_iso8601(_) do
    nil
  end

  def prepare_brainstormings_from_local_storage(brainstormings_stored) do
    if is_list(brainstormings_stored) do
      brainstormings_stored
      |> Enum.map(fn e ->
        Map.put(e, "last_accessed_at", format_iso8601(e["last_accessed_at"]))
      end)
      |> Enum.filter(&valid_stored_brainstorming?/1)
    else
      []
    end
  end

  def prepare_brainstormings_from_session(brainstormings, user) do
    Enum.map(brainstormings, fn brainstorming ->
      %{
        "last_accessed_at" => brainstorming.last_accessed_at,
        "name" => brainstorming.name,
        "id" => brainstorming.id,
        "admin_url_id" =>
          if(has_moderating_permission(brainstorming, user),
            do: brainstorming.admin_url_id,
            else: nil
          )
      }
    end)
  end

  def prepare_initial_brainstormings(
        brainstormings_from_local_storage,
        brainstormings_from_session,
        user
      ) do
    (prepare_brainstormings_from_local_storage(brainstormings_from_local_storage) ++
       prepare_brainstormings_from_session(brainstormings_from_session, user))
    |> Enum.uniq()
    |> Enum.sort(&(&1["last_accessed_at"] > &2["last_accessed_at"]))
  end

  def valid_stored_brainstorming?(brainstorming) do
    case Ecto.UUID.cast(brainstorming["id"]) do
      {:ok, _} -> brainstorming["last_accessed_at"] && brainstorming["name"]
      :error -> false
    end
  end
end
