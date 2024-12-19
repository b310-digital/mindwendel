defmodule Mindwendel.LocalStorage do
  alias Mindwendel.Permissions

  @moduledoc """
  The LocalStorage context. It includes helpers to handle local storage data from clients.
  """

  # This function is used to merge the brainstormings from local storage and the session.
  # It returns a list of brainstormings sorted by the last_accessed_at field.
  def brainstormings_from_local_storage_and_session(
        brainstormings_from_local_storage,
        brainstormings_from_session,
        user
      ) do
    (brainstormings_from_local_storage(brainstormings_from_local_storage) ++
       brainstormings_from_session(brainstormings_from_session, user))
    |> Enum.uniq_by(& &1["id"])
    |> Enum.sort(&(&1["last_accessed_at"] > &2["last_accessed_at"]))
  end

  defp brainstormings_from_local_storage(brainstormings_stored)
       when is_list(brainstormings_stored) do
    brainstormings_stored
    |> Enum.map(fn e ->
      Map.put(e, "last_accessed_at", format_iso8601(e["last_accessed_at"]))
    end)
    |> Enum.filter(&valid_stored_brainstorming?/1)
  end

  defp brainstormings_from_local_storage(_) do
    []
  end

  defp brainstormings_from_session(brainstormings, user) when is_list(brainstormings) do
    Enum.map(brainstormings, fn brainstorming ->
      %{
        "last_accessed_at" => brainstorming.last_accessed_at,
        "name" => brainstorming.name,
        "id" => brainstorming.id,
        "admin_url_id" =>
          if(Permissions.has_moderating_permission(brainstorming, user),
            do: brainstorming.admin_url_id,
            else: nil
          )
      }
    end)
  end

  defp brainstormings_from_session(_, _) do
    []
  end

  defp valid_stored_brainstorming?(brainstorming) do
    case Ecto.UUID.cast(brainstorming["id"]) do
      {:ok, _} -> brainstorming["last_accessed_at"] && brainstorming["name"]
      :error -> false
    end
  end

  defp format_iso8601(iso8601) when iso8601 != nil do
    case DateTime.from_iso8601(iso8601) do
      {:ok, date_time, _} -> date_time
      {:error, _} -> nil
    end
  end

  defp format_iso8601(_) do
    nil
  end
end
