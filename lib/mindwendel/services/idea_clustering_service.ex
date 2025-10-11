defmodule Mindwendel.Services.IdeaClusteringService do
  @moduledoc """
  Coordinates AI-powered clustering of ideas into existing brainstorming labels.

  The service prepares the prompt payload, delegates classification to the chat
  completions service, and persists the resulting assignments in a single batch.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Ideas
  alias Mindwendel.Repo
  alias Mindwendel.Services.ChatCompletions.ChatCompletionsService

  @type clustering_assignment :: %{
          required(:idea_id) => String.t(),
          required(:label_ids) => [String.t()],
          optional(:new_labels) => list(map())
        }

  @doc """
  Runs the clustering pipeline for the provided brainstorming.

  Returns:
    * `{:ok, assignments}` when clustering succeeds (assignments may be empty).
    * `{:ok, :skipped}` when the feature is disabled or there is nothing to cluster.
    * `{:error, reason}` when the AI classification fails.
  """
  @spec cluster_labels(Brainstorming.t()) ::
          {:ok, [clustering_assignment()]}
          | {:ok, :skipped}
          | {:error, term()}
  def cluster_labels(%Brainstorming{} = brainstorming) do
    if clustering_enabled?() do
      do_cluster_labels(brainstorming)
    else
      {:ok, :skipped}
    end
  end

  defp do_cluster_labels(brainstorming) do
    brainstorming = preload_brainstorming(brainstorming)
    ideas = Ideas.list_ideas_for_brainstorming(brainstorming.id)

    cond do
      Enum.empty?(brainstorming.labels) ->
        Logger.debug("Skipping AI clustering for #{brainstorming.id}: no labels available")
        {:ok, :skipped}

      Enum.empty?(ideas) ->
        Logger.debug("Skipping AI clustering for #{brainstorming.id}: no ideas to cluster")
        {:ok, :skipped}

      true ->
        locale = Gettext.get_locale(MindwendelWeb.Gettext)
        label_payload = build_label_payload(brainstorming.labels)
        idea_payload = build_idea_payload(ideas)

        case ChatCompletionsService.classify_labels(
               brainstorming.name,
               label_payload,
               idea_payload,
               locale
             ) do
          {:ok, raw_assignments} ->
            handle_assignments(brainstorming, ideas, raw_assignments)

          {:error, reason} ->
            Logger.error("AI clustering failed for #{brainstorming.id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp handle_assignments(brainstorming, ideas, raw_assignments) do
    idea_ids = MapSet.new(Enum.map(ideas, & &1.id))
    existing_label_ids = MapSet.new(Enum.map(brainstorming.labels, & &1.id))

    normalized_assignments =
      raw_assignments
      |> Enum.map(&normalize_assignment/1)
      |> Enum.filter(&valid_assignment?/1)

    log_ignored_label_suggestions(
      normalized_assignments,
      brainstorming.id,
      existing_label_ids
    )

    case Repo.transaction(fn ->
           with {:ok, label_lookup, valid_label_ids} <-
                  ensure_label_resources(brainstorming, normalized_assignments) do
             assignments =
               normalized_assignments
               |> apply_new_labels_to_assignments(label_lookup)
               |> Enum.filter(fn %{idea_id: idea_id} -> MapSet.member?(idea_ids, idea_id) end)
               |> Enum.map(&sanitize_assignment(&1, valid_label_ids))

             case IdeaLabels.replace_labels_for_brainstorming(brainstorming.id, assignments) do
               {:ok, _count} -> assignments
               {:error, reason} -> Repo.rollback(reason)
             end
           else
             {:error, reason} -> Repo.rollback(reason)
           end
         end) do
      {:ok, assignments} ->
        Logger.info(
          "AI clustering applied to #{length(assignments)} ideas in brainstorming #{brainstorming.id}"
        )

        {:ok, assignments}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sanitize_assignment(
         %{idea_id: idea_id, label_ids: label_ids} = assignment,
         valid_label_ids
       ) do
    sanitized_label_ids =
      label_ids
      |> Enum.filter(&MapSet.member?(valid_label_ids, &1))
      |> Enum.uniq()

    %{assignment | idea_id: idea_id, label_ids: sanitized_label_ids}
  end

  defp build_label_payload(labels) do
    placeholder_names = placeholder_label_names()

    Enum.map(labels, fn label ->
      base_payload = %{
        id: label.id,
        name: label.name
      }

      case label_rename_hint(label, placeholder_names) do
        nil -> base_payload
        hint -> Map.put(base_payload, :rename_hint, hint)
      end
    end)
  end

  defp build_idea_payload(ideas) do
    Enum.map(ideas, fn idea ->
      %{
        id: idea.id,
        text: idea.body
      }
    end)
  end

  defp log_ignored_label_suggestions(assignments, brainstorming_id, existing_label_ids) do
    ignored =
      assignments
      |> Enum.flat_map(&Map.get(&1, :new_labels, []))
      |> Enum.reject(fn suggestion ->
        case suggestion do
          %{id: id} when is_binary(id) ->
            MapSet.member?(existing_label_ids, id)

          _ ->
            false
        end
      end)

    case ignored do
      [] ->
        :ok

      _ ->
        Logger.info(
          "AI clustering suggested #{length(ignored)} non-existent labels for brainstorming #{brainstorming_id}, ignoring: #{inspect(ignored)}"
        )
    end
  end

  def clustering_enabled? do
    ChatCompletionsService.enabled?()
  end

  defp normalize_assignment(%{} = assignment) do
    %{
      idea_id: get_assignment_value(assignment, :idea_id),
      label_ids:
        assignment
        |> get_assignment_value(:label_ids, [])
        |> normalize_label_ids(),
      new_labels:
        assignment
        |> get_assignment_value(:new_labels, [])
        |> normalize_new_labels()
    }
  end

  defp normalize_assignment(_), do: %{idea_id: nil, label_ids: [], new_labels: []}

  defp normalize_label_ids(ids) when is_list(ids) do
    ids
    |> Enum.filter(&valid_label_id?/1)
  end

  defp normalize_label_ids(_), do: []

  defp normalize_new_labels(labels) when is_list(labels) do
    labels
    |> Enum.map(fn
      %{} = label ->
        %{
          id:
            label
            |> get_assignment_value(:id)
            |> normalize_label_id(),
          name:
            label
            |> get_assignment_value(:name)
            |> normalize_label_text(),
          color:
            label
            |> get_assignment_value(:color)
            |> normalize_color_text()
        }

      _ ->
        %{id: nil, name: nil, color: nil}
    end)
    |> Enum.filter(&valid_new_label?/1)
  end

  defp normalize_new_labels(_), do: []

  defp valid_assignment?(%{idea_id: idea_id}) when is_binary(idea_id) and idea_id != "", do: true
  defp valid_assignment?(_), do: false

  defp valid_new_label?(%{id: id, name: name}) do
    (is_binary(id) and id != "") or (is_binary(name) and String.trim(name) != "")
  end

  defp valid_new_label?(_), do: false

  defp valid_label_id?(value) when is_binary(value), do: String.trim(value) != ""
  defp valid_label_id?(_), do: false

  defp get_assignment_value(map, key, default \\ nil) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} when not is_nil(value) ->
        value

      _ ->
        Map.get(map, to_string(key), default)
    end
  end

  defp ensure_label_resources(brainstorming, assignments) do
    suggestions =
      assignments
      |> Enum.flat_map(&Map.get(&1, :new_labels, []))

    existing_by_id =
      brainstorming.labels
      |> Enum.reduce(%{}, fn label, acc ->
        Map.put(acc, label.id, label)
      end)

    with {:ok, planned_updates} <- plan_label_changes(existing_by_id, suggestions),
         {:ok, updated_by_id} <- apply_label_updates(existing_by_id, planned_updates) do
      valid_label_ids = updated_by_id |> Map.keys() |> MapSet.new()

      existing_by_name =
        Enum.reduce(updated_by_id, %{}, fn {_id, label}, acc ->
          case normalize_label_name(label.name) do
            nil -> acc
            key -> Map.put(acc, key, label)
          end
        end)

      lookup = %{
        by_id: updated_by_id,
        existing_by_name: existing_by_name
      }

      {:ok, lookup, valid_label_ids}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp plan_label_changes(existing_by_id, suggestions) do
    updates =
      suggestions
      |> Enum.reduce(%{}, fn
        %{id: id} = suggestion, acc when is_binary(id) and id != "" ->
          if Map.has_key?(existing_by_id, id) do
            acc
            |> maybe_put_update(id, :name, suggestion.name)
            |> maybe_put_update(id, :color, suggestion.color)
          else
            acc
          end

        _suggestion, acc ->
          acc
      end)

    {:ok, updates}
  end

  defp apply_label_updates(existing_by_id, updates) do
    Enum.reduce_while(updates, {:ok, existing_by_id}, fn {label_id, attrs}, {:ok, acc_by_id} ->
      case Map.get(acc_by_id, label_id) do
        nil ->
          {:halt, {:error, {:label_not_found, label_id}}}

        label ->
          changes =
            attrs
            |> Enum.reduce(%{}, fn
              {:name, value}, changes ->
                if is_binary(value) and value != label.name do
                  Map.put(changes, :name, value)
                else
                  changes
                end

              {:color, value}, changes ->
                cond do
                  is_nil(value) -> changes
                  value == label.color -> changes
                  true -> Map.put(changes, :color, value)
                end

              _, changes ->
                changes
            end)

          if map_size(changes) == 0 do
            {:cont, {:ok, acc_by_id}}
          else
            case label |> IdeaLabel.changeset(changes) |> Repo.update() do
              {:ok, updated_label} ->
                {:cont, {:ok, Map.put(acc_by_id, label_id, updated_label)}}

              {:error, changeset} ->
                {:halt, {:error, {:label_update_failed, label_id, changeset}}}
            end
          end
      end
    end)
  end

  defp maybe_put_update(updates, _label_id, _field, value)
       when value in [nil, ""],
       do: updates

  defp maybe_put_update(updates, label_id, field, value) when field in [:name, :color] do
    cleaned_value =
      case field do
        :name -> normalize_label_text(value)
        :color -> normalize_color_text(value)
      end

    if is_nil(cleaned_value) do
      updates
    else
      existing = Map.get(updates, label_id, %{})
      Map.put(updates, label_id, Map.put(existing, field, cleaned_value))
    end
  end

  defp apply_new_labels_to_assignments(assignments, %{by_id: _} = lookup) do
    Enum.map(assignments, fn assignment ->
      new_label_ids =
        assignment
        |> Map.get(:new_labels, [])
        |> Enum.flat_map(&resolve_label_id(&1, lookup))

      %{assignment | label_ids: assignment.label_ids ++ new_label_ids}
    end)
  end

  defp resolve_label_id(%{id: id} = _suggestion, %{by_id: by_id}) when is_binary(id) do
    case Map.get(by_id, id) do
      %IdeaLabel{id: label_id} -> [label_id]
      _ -> []
    end
  end

  defp resolve_label_id(%{name: name}, %{existing_by_name: existing_by_name})
       when is_binary(name) do
    case normalize_label_name(name) do
      nil ->
        []

      key ->
        case Map.get(existing_by_name, key) do
          %IdeaLabel{id: label_id} -> [label_id]
          _ -> []
        end
    end
  end

  defp resolve_label_id(_, _), do: []

  defp normalize_label_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_label_text(_), do: nil

  defp normalize_label_id(value) when is_binary(value) do
    case String.trim(value) do
      "" ->
        nil

      trimmed ->
        case Ecto.UUID.cast(trimmed) do
          {:ok, uuid} -> uuid
          :error -> nil
        end
    end
  end

  defp normalize_label_id(_), do: nil

  defp normalize_color_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> String.downcase(trimmed)
    end
  end

  defp normalize_color_text(_), do: nil

  defp placeholder_label_names do
    Brainstorming.idea_label_factory()
    |> Enum.map(&label_placeholder_key/1)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp label_placeholder_key(%IdeaLabel{name: name}) do
    normalize_label_name(name)
  end

  defp label_placeholder_key(_), do: nil

  defp label_rename_hint(%IdeaLabel{name: name} = label, placeholder_names) do
    normalized = normalize_label_name(name)

    cond do
      is_nil(normalized) ->
        nil

      MapSet.member?(placeholder_names, normalized) ->
        "Rename to match the ideas you assign; \"#{label.name}\" is only a placeholder color."

      String.contains?(normalized, "label") ->
        "Rename to a descriptive theme; \"#{label.name}\" sounds generic."

      true ->
        nil
    end
  end

  defp label_rename_hint(_, _), do: nil

  defp normalize_label_name(value) when is_binary(value) do
    case normalize_label_text(value) do
      nil -> nil
      trimmed -> String.downcase(trimmed)
    end
  end

  defp normalize_label_name(_), do: nil

  defp preload_brainstorming(brainstorming) do
    Repo.preload(brainstorming, [
      :labels,
      lanes:
        from(l in Lane,
          order_by: [
            asc: l.position_order,
            asc: l.inserted_at
          ]
        )
    ])
  end
end
