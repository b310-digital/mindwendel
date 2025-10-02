defmodule Mindwendel.AI.Schemas.IdeaResponse do
  @moduledoc """
  Embedded schema for validating LLM-generated idea responses.

  This schema is used to validate JSON responses from AI providers
  without persisting the data to the database. Similar to how Zod
  is used in JavaScript for runtime validation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :idea, :string
    field :rationale, :string
    field :lane_id, :string
  end

  @doc """
  Creates a changeset for validating an idea response.

  ## Validations
  - `idea` is required
  - `idea` must be between 1 and 1023 characters
  - `rationale` is optional but if present, must be between 1 and 2000 characters

  ## Examples

      iex> changeset(%IdeaResponse{}, %{"idea" => "My great idea"})
      %Ecto.Changeset{valid?: true}

      iex> changeset(%IdeaResponse{}, %{})
      %Ecto.Changeset{valid?: false, errors: [idea: {"can't be blank", _}]}
  """
  def changeset(idea_response, attrs) do
    idea_response
    |> cast(attrs, [:idea, :rationale, :lane_id])
    |> validate_required([:idea])
    |> validate_length(:idea, min: 1, max: 1023)
    |> validate_length(:rationale, min: 1, max: 2000)
  end

  @doc """
  Validates and parses a list of idea responses from an LLM.

  Returns `{:ok, ideas}` if all ideas are valid, or `{:error, errors}`
  with detailed validation errors if any ideas are invalid.

  ## Examples

      iex> validate_ideas([%{"idea" => "Test"}])
      {:ok, [%{"idea" => "Test"}]}

      iex> validate_ideas([%{"idea" => ""}])
      {:error, %{0 => %{idea: ["should be at least 1 character(s)"]}}}
  """
  def validate_ideas(ideas) when is_list(ideas) do
    ideas
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {idea_data, index}, {:ok, acc} ->
      changeset = changeset(%__MODULE__{}, idea_data)

      if changeset.valid? do
        validated_idea = apply_changes(changeset)
        {:cont, {:ok, acc ++ [validated_idea]}}
      else
        errors = format_errors(changeset, index)
        {:halt, {:error, errors}}
      end
    end)
  end

  def validate_ideas(_), do: {:error, %{base: ["expected a list of ideas"]}}

  # Private helper to format changeset errors in a readable way
  defp format_errors(changeset, index) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{index => errors}
  end
end
