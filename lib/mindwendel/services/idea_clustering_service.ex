defmodule Mindwendel.Services.IdeaClusteringService do
  @moduledoc """
  Coordinates AI-powered clustering of ideas into existing brainstorming labels.

  The service prepares the prompt payload, delegates classification to the chat
  completions service, and persists the resulting assignments in a single batch.
  """

  require Logger

  alias Mindwendel.AI.Schemas.IdeaLabelAssignment
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Ideas
  alias Mindwendel.Repo
  alias Mindwendel.Services.ChatCompletions.ChatCompletionsService

  @type clustering_assignment :: %{
          required(:idea_id) => String.t(),
          required(:label_ids) => [String.t()]
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
            with {:ok, assignments} <- IdeaLabelAssignment.cast_assignments(raw_assignments) do
              handle_assignments(brainstorming, ideas, assignments)
            else
              {:error, validation_errors} ->
                Logger.error(
                  "AI clustering returned invalid assignments for #{brainstorming.id}: #{inspect(validation_errors)}"
                )

                {:error, {:invalid_assignments, validation_errors}}
            end

          {:error, reason} ->
            Logger.error("AI clustering failed for #{brainstorming.id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp handle_assignments(brainstorming, ideas, assignments) do
    idea_ids = MapSet.new(Enum.map(ideas, & &1.id))
    existing_label_ids = MapSet.new(Enum.map(brainstorming.labels, & &1.id))

    log_ignored_label_suggestions(
      assignments,
      brainstorming.id,
      existing_label_ids
    )

    case Repo.transaction(fn ->
           with {:ok, label_lookup, valid_label_ids} <-
                  ensure_label_resources(brainstorming, assignments) do
             assignments =
               assignments
               |> apply_new_labels_to_assignments(label_lookup)
               |> Enum.filter(fn assignment -> MapSet.member?(idea_ids, assignment.idea_id) end)
               |> Enum.map(&sanitize_assignment(&1, valid_label_ids))
               |> Enum.map(&assignment_to_map/1)

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

  defp sanitize_assignment(%IdeaLabelAssignment{} = assignment, valid_label_ids) do
    sanitized_label_ids =
      assignment.label_ids
      |> Enum.filter(&MapSet.member?(valid_label_ids, &1))
      |> Enum.uniq()

    %{assignment | label_ids: sanitized_label_ids}
  end

  defp assignment_to_map(%IdeaLabelAssignment{} = assignment) do
    %{
      idea_id: assignment.idea_id,
      label_ids: assignment.label_ids
    }
  end

  defp build_label_payload(labels) do
    Enum.map(labels, fn label ->
      %{
        id: label.id,
        name: label.name
      }
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
      |> Enum.flat_map(& &1.new_labels)
      |> Enum.filter(fn
        %IdeaLabelAssignment.NewLabel{id: id} when is_binary(id) ->
          not MapSet.member?(existing_label_ids, id)

        _ ->
          false
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

  defp ensure_label_resources(brainstorming, assignments) do
    existing_by_id =
      brainstorming.labels
      |> Enum.reduce(%{}, fn label, acc ->
        Map.put(acc, label.id, label)
      end)

    case apply_label_renames(existing_by_id, assignments) do
      {:ok, updated_by_id} ->
        valid_label_ids = updated_by_id |> Map.keys() |> MapSet.new()

        lookup = %{
          by_id: updated_by_id
        }

        {:ok, lookup, valid_label_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_label_renames(existing_by_id, assignments) do
    assignments
    |> Enum.flat_map(& &1.new_labels)
    |> Enum.reduce_while({:ok, existing_by_id}, fn suggestion, {:ok, acc} ->
      case rename_label(acc, suggestion) do
        {:ok, updated_acc} -> {:cont, {:ok, updated_acc}}
        :skip -> {:cont, {:ok, acc}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp rename_label(acc, %IdeaLabelAssignment.NewLabel{id: id, name: name}) do
    with true <- is_binary(id),
         true <- String.trim(id) != "",
         %IdeaLabel{} = label <- Map.get(acc, id),
         trimmed_name when is_binary(trimmed_name) <- sanitize_label_name(name),
         true <- trimmed_name != label.name do
      case label |> IdeaLabel.changeset(%{name: trimmed_name}) |> Repo.update() do
        {:ok, updated_label} ->
          {:ok, Map.put(acc, id, updated_label)}

        {:error, changeset} ->
          {:error, {:label_update_failed, id, changeset}}
      end
    else
      _ -> :skip
    end
  end

  defp rename_label(_acc, _), do: :skip

  defp apply_new_labels_to_assignments(assignments, %{by_id: labels_by_id}) do
    Enum.map(assignments, fn %IdeaLabelAssignment{} = assignment ->
      new_label_ids =
        assignment.new_labels
        |> Enum.map(& &1.id)
        |> Enum.filter(&Map.has_key?(labels_by_id, &1))

      updated_label_ids =
        assignment.label_ids
        |> Enum.concat(new_label_ids)
        |> Enum.uniq()

      %{assignment | label_ids: updated_label_ids}
    end)
  end

  defp sanitize_label_name(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp sanitize_label_name(_), do: nil

  defp preload_brainstorming(brainstorming), do: Repo.preload(brainstorming, :labels)
end
