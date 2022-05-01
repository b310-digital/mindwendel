defmodule Mindwendel.Brainstormings.IdeaLabelFactory do
  alias Mindwendel.Brainstormings.Brainstorming

  def build_idea_label(list) when is_list(list) do
    rem(
      length(list),
      length(idea_label_variants())
    )
    |> idea_label_variant()
  end

  def build_idea_label(%Brainstorming{labels: brainstorming_labels}) do
    build_idea_label(brainstorming_labels)
  end

  def build_idea_label(nil) do
    idea_label_variant(0)
  end

  def idea_label_variant(variant_number) when is_integer(variant_number) do
    Enum.at(idea_label_variants(), variant_number)
  end

  def idea_label_variants do
    Brainstorming.idea_label_factory()
  end
end
