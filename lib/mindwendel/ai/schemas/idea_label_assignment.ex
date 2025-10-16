defmodule Mindwendel.AI.Schemas.IdeaLabelAssignment do
  @moduledoc """
  Embedded schema used to validate LLM responses for idea-to-label assignments.

  Each entry represents a single idea with the ids of the labels assigned by the AI.
  """

  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  @primary_key false
  embedded_schema do
    field :idea_id, :string
    field :label_ids, {:array, :string}, default: []
  end

  @type t :: %__MODULE__{
          idea_id: String.t() | nil,
          label_ids: [String.t()]
        }

  @doc """
  Builds a changeset for a single assignment entry.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:idea_id, :label_ids])
    |> validate_required([:idea_id, :label_ids])
    |> validate_length(:idea_id, min: 1, max: 255)
  end

  @doc """
  Casts a list of assignments returned by the AI model into typed structs.

  Returns `{:ok, [IdeaLabelAssignment.t()]}` on success,
  or `{:error, errors}` with index-keyed error maps.
  """
  @spec cast_assignments(any()) ::
          {:ok, [t()]}
          | {:error, %{base: [String.t()]}}
          | {:error, %{optional(non_neg_integer()) => map()}}
  def cast_assignments(assignments) when is_list(assignments) do
    assignments
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {attrs, index}, {:ok, acc} ->
      changeset = changeset(%__MODULE__{}, attrs)

      if changeset.valid? do
        {:cont, {:ok, [apply_changes(changeset) | acc]}}
      else
        {:halt, {:error, format_errors(changeset, index)}}
      end
    end)
    |> case do
      {:ok, structs} -> {:ok, structs}
      {:error, _} = error -> error
    end
  end

  def cast_assignments(_), do: {:error, %{base: ["expected a list of assignments"]}}

  defp format_errors(changeset, index) do
    Logger.debug("Invalid AI label assignment at index #{index}: #{inspect(changeset.errors)}")
    %{index => %{base: ["invalid assignment data"]}}
  end
end
