defmodule Mindwendel.AI.Schemas.IdeaLabelAssignment do
  @moduledoc """
  Embedded schema used to validate LLM responses for idea-to-label assignments.

  The schema mirrors the JSON structure expected from the AI classifier:

      [
        %{
          "idea_id" => "uuid",
          "label_ids" => ["uuid", ...],
          "new_labels" => [
            %{"name" => "Label name", "color" => "#ffffff"}
          ]
        }
      ]

  Validation ensures we only persist correctly formatted assignment data.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Phoenix.HTML, only: [html_escape: 1]

  alias __MODULE__.NewLabel
  alias Phoenix.HTML.Safe

  @primary_key false
  embedded_schema do
    field :idea_id, :string
    field :label_ids, {:array, :string}, default: []
    embeds_many :new_labels, NewLabel
  end

  @type t :: %__MODULE__{
          idea_id: String.t() | nil,
          label_ids: [String.t()],
          new_labels: [NewLabel.t()]
        }

  defmodule NewLabel do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :id, :string
      field :name, :string
      field :color, :string
    end

    @type t :: %__MODULE__{
            id: String.t() | nil,
            name: String.t() | nil,
            color: String.t() | nil
          }

    def changeset(new_label, attrs) do
      new_label
      |> cast(attrs, [:id, :name, :color])
      |> validate_change(:id, &validate_uuid/2)
      |> validate_change(:name, &validate_name_length/2)
      |> validate_change(:color, &validate_color_format/2)
      |> ensure_identifier_present()
    end

    defp validate_uuid(:id, nil), do: []

    defp validate_uuid(:id, value) do
      case Ecto.UUID.cast(value) do
        {:ok, _uuid} -> []
        :error -> [id: "is not a valid UUID"]
      end
    end

    defp validate_name_length(:name, nil), do: []

    defp validate_name_length(:name, value) do
      trimmed = String.trim(value)

      cond do
        byte_size(trimmed) < 1 ->
          [name: "can't be blank"]

        byte_size(trimmed) > 120 ->
          [name: "should be at most 120 character(s)"]

        true ->
          []
      end
    end

    defp validate_color_format(:color, nil), do: []

    defp validate_color_format(:color, value) do
      if Regex.match?(~r/^#[0-9a-fA-F]{6}$/, value) do
        []
      else
        [color: "has invalid format"]
      end
    end

    defp ensure_identifier_present(%Ecto.Changeset{} = changeset) do
      id = fetch_field!(changeset, :id)
      name = fetch_field!(changeset, :name)

      if (is_nil(id) or id == "") and (is_nil(name) or String.trim(name) == "") do
        add_error(changeset, :id, "must include either an id or name")
      else
        changeset
      end
    end
  end

  @doc """
  Builds a changeset for a single assignment entry.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:idea_id, :label_ids])
    |> validate_required([:idea_id, :label_ids])
    |> validate_length(:idea_id, min: 1, max: 255)
    |> cast_embed(:new_labels, with: &NewLabel.changeset/2)
  end

  @doc """
  Validates a list of assignments returned by the AI model.

  Returns `{:ok, [assignment]}` with hydrated structs on success,
  or `{:error, errors}` with index-keyed error maps.
  """
  @spec validate_assignments(any()) ::
          {:ok, list(map())}
          | {:error, %{base: [String.t()]}}
          | {:error, %{optional(non_neg_integer()) => map()}}
  def validate_assignments(assignments) when is_list(assignments) do
    assignments
    |> Enum.reduce_while({:ok, 0, []}, fn attrs, {:ok, index, acc} ->
      changeset = changeset(%__MODULE__{}, attrs)

      if changeset.valid? do
        validated =
          changeset
          |> apply_changes()
          |> to_result_map()

        {:cont, {:ok, index + 1, [validated | acc]}}
      else
        {:halt, {:error, format_errors(changeset, index)}}
      end
    end)
    |> finalize_validation_result()
  end

  def validate_assignments(_), do: {:error, %{base: ["expected a list of assignments"]}}

  defp to_result_map(%__MODULE__{} = assignment) do
    %{
      idea_id: assignment.idea_id,
      label_ids: assignment.label_ids || [],
      new_labels:
        assignment.new_labels
        |> Enum.map(&%{id: &1.id, name: &1.name, color: &1.color})
    }
  end

  defp finalize_validation_result({:ok, _index, acc}), do: {:ok, Enum.reverse(acc)}
  defp finalize_validation_result({:error, _} = error), do: error

  defp format_errors(changeset, index) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        msg
        |> replace_interpolations(opts)
        |> html_escape()
        |> Safe.to_iodata()
        |> IO.iodata_to_binary()
      end)

    %{index => errors}
  end

  defp replace_interpolations(msg, opts) do
    Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
      opts
      |> find_interpolation_value(key)
      |> to_string()
    end)
  end

  defp find_interpolation_value(opts, key) do
    Enum.find_value(opts, key, fn {opt_key, value} ->
      if to_string(opt_key) == key, do: value
    end)
  end
end
