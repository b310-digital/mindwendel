defmodule Mindwendel.AI.Schemas.LabelRename do
  @moduledoc """
  Embedded schema used to validate label rename suggestions produced by the AI.

  Each entry identifies an existing label by id and provides a concise replacement name.
  """

  use Ecto.Schema
  import Ecto.Changeset

  require Logger

  @primary_key false
  embedded_schema do
    field :id, :string
    field :name, :string
  end

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil
        }

  @doc """
  Casts and validates a list of rename suggestions.

  Returns `{:ok, [%{id: id, name: name}]}` when the payload is valid, or
  `{:error, errors}` when the structure is invalid.
  """
  @spec cast_label_renames(any()) ::
          {:ok, [map()]}
          | {:error, %{base: [String.t()]}}
          | {:error, %{optional(non_neg_integer()) => map()}}
  def cast_label_renames(renames) when is_list(renames) do
    renames
    |> Enum.reduce_while({:ok, 0, []}, fn attrs, {:ok, index, acc} ->
      changeset = changeset(%__MODULE__{}, attrs)

      if changeset.valid? do
        {:cont, {:ok, index + 1, [apply_changes(changeset) | acc]}}
      else
        {:halt, {:error, format_errors(changeset, index)}}
      end
    end)
    |> finalize_cast_result()
  end

  def cast_label_renames(_), do: {:error, %{base: ["expected a list of label rename entries"]}}

  defp changeset(rename, attrs) do
    rename
    |> cast(attrs, [:id, :name])
    |> validate_required([:id, :name])
    |> validate_change(:id, &validate_uuid/2)
    |> update_change(:name, &normalize_name/1)
    |> validate_length(:name, min: 2, max: 15)
    |> validate_change(:name, &validate_word_count/2)
  end

  defp validate_uuid(:id, value) do
    case Ecto.UUID.cast(value) do
      {:ok, _uuid} -> []
      :error -> [id: "is not a valid UUID"]
    end
  end

  defp validate_word_count(:name, value) when is_binary(value) do
    words = String.split(value, ~r/\s+/, trim: true)

    if length(words) > 2 do
      [name: "should use at most two words"]
    else
      []
    end
  end

  defp validate_word_count(:name, _), do: [name: "must be a string"]

  defp finalize_cast_result({:ok, _index, acc}) do
    {:ok,
     Enum.map(Enum.reverse(acc), fn %{id: id, name: name} ->
       %{id: id, name: name}
     end)}
  end

  defp finalize_cast_result({:error, _} = error), do: error

  defp format_errors(changeset, index) do
    Logger.debug("Invalid AI label rename entry at index #{index}: #{inspect(changeset.errors)}")
    %{index => %{base: ["invalid label rename data"]}}
  end

  defp normalize_name(value) when is_binary(value), do: String.trim(value)
  defp normalize_name(value), do: value
end
