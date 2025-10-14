defmodule Mindwendel.Services.IdeaClusteringService do
  @moduledoc """
  Coordinates AI-powered clustering of ideas into existing brainstorming labels.

  The service prepares the prompt payload, delegates classification to the chat
  completions service, and persists the resulting assignments in a single batch.
  """

  require Logger

  alias Ecto.UUID
  alias Mindwendel.AI.Schemas.IdeaLabelAssignment
  alias Mindwendel.Brainstormings.Brainstorming
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

        with {:ok, raw_assignments} <-
               ChatCompletionsService.classify_labels(
                 brainstorming.name,
                 label_payload,
                 idea_payload,
                 locale
               ),
             {:ok, assignments} <- normalize_assignments(raw_assignments) do
          Logger.debug(fn ->
            truncated =
              raw_assignments
              |> inspect(limit: 15, printable_limit: 300, width: 80)

            "AI clustering raw assignments: #{truncated}"
          end)

          handle_assignments(brainstorming, ideas, assignments)
        else
          {:error, %{} = validation_errors} ->
            Logger.error(
              "AI clustering returned invalid assignments for #{brainstorming.id}: #{inspect(validation_errors)}"
            )

            {:error, {:invalid_assignments, validation_errors}}

          {:error, reason} ->
            Logger.error("AI clustering failed for #{brainstorming.id}: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp handle_assignments(brainstorming, ideas, assignments) do
    idea_ids = build_uuid_set(Enum.map(ideas, & &1.id))
    existing_label_ids = build_uuid_set(Enum.map(brainstorming.labels, & &1.id))

    case Repo.transaction(fn ->
           persist_assignments(
             brainstorming,
             assignments,
             idea_ids,
             existing_label_ids
           )
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
         %IdeaLabelAssignment{} = assignment,
         valid_idea_ids,
         valid_label_ids
       ) do
    sanitized_idea_id = normalize_uuid(assignment.idea_id)

    cond do
      is_nil(sanitized_idea_id) ->
        nil

      not MapSet.member?(valid_idea_ids, sanitized_idea_id) ->
        nil

      true ->
        sanitized_label_ids =
          assignment.label_ids
          |> Enum.map(&normalize_label_id/1)
          |> Enum.filter(&valid_label_id?(&1, valid_label_ids))
          |> Enum.uniq()

        %{assignment | idea_id: sanitized_idea_id, label_ids: sanitized_label_ids}
    end
  end

  defp assignment_to_map(%IdeaLabelAssignment{} = assignment) do
    %{
      idea_id: assignment.idea_id,
      label_ids: assignment.label_ids
    }
  end

  defp build_uuid_set(values) do
    Enum.reduce(values, MapSet.new(), fn value, acc ->
      case normalize_uuid(value) do
        nil -> acc
        uuid -> MapSet.put(acc, uuid)
      end
    end)
  end

  defp normalize_uuid(%{"id" => id}), do: normalize_uuid(id)
  defp normalize_uuid(%{id: id}), do: normalize_uuid(id)

  defp normalize_uuid(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      nil
    else
      case UUID.cast(trimmed) do
        {:ok, uuid} -> uuid
        :error -> nil
      end
    end
  end

  defp normalize_uuid(_value), do: nil

  defp normalize_label_id(value), do: normalize_uuid(value)

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

  def clustering_enabled? do
    ChatCompletionsService.enabled?()
  end

  defp preload_brainstorming(brainstorming), do: Repo.preload(brainstorming, :labels)

  defp persist_assignments(brainstorming, assignments, idea_ids, valid_label_ids) do
    assignments
    |> Enum.map(&sanitize_assignment(&1, idea_ids, valid_label_ids))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&assignment_to_map/1)
    |> apply_assignments(brainstorming.id)
  end

  defp apply_assignments(assignments, brainstorming_id) do
    case IdeaLabels.replace_labels_for_brainstorming(brainstorming_id, assignments) do
      {:ok, _count} -> assignments
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp normalize_assignments(assignments) when is_list(assignments) do
    if Enum.all?(assignments, &match?(%IdeaLabelAssignment{}, &1)) do
      {:ok, assignments}
    else
      IdeaLabelAssignment.cast_assignments(assignments)
    end
  end

  defp normalize_assignments(%{"assignments" => assignments}),
    do: normalize_assignments(assignments)

  defp normalize_assignments(%{assignments: assignments}),
    do: normalize_assignments(assignments)

  defp normalize_assignments(assignments) when is_binary(assignments) do
    case String.trim(assignments) do
      "" ->
        {:error, :invalid_assignments_format}

      trimmed ->
        case Jason.decode(trimmed) do
          {:ok, decoded} -> normalize_assignments(decoded)
          {:error, _reason} -> {:error, :invalid_assignments_format}
        end
    end
  end

  defp normalize_assignments(_), do: {:error, :invalid_assignments_format}

  defp valid_label_id?(nil, _valid_label_ids), do: false

  defp valid_label_id?(label_id, valid_label_ids) do
    MapSet.member?(valid_label_ids, label_id)
  end
end
