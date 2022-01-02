defmodule Mindwendel.Repo.DataMigrations.MigrateIdealLabels do
  import Ecto.Query
  import Ecto.Changeset
  import MindwendelWeb.Gettext

  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea

  @deprecated_label_to_idea_label_name_mapping %{
    label_1: gettext("cyan"),
    label_2: gettext("gray dark"),
    label_3: gettext("green"),
    label_4: gettext("red"),
    label_5: gettext("yellow")
  }

  def run do
    prepare_labels_for_brainstormings()

    migrate_labels_from_ideas()
  end

  def prepare_labels_for_brainstormings do
    Repo.transaction(fn ->
      # Note: This following code works, but will load the query result into memory. This can cause problems on larger databases.
      # We should be ok considering that it is a relatively new project.
      from(Brainstorming, preload: [:labels])
      |> Repo.all()
      |> Enum.each(&migrate_labels_to_idea_labels/1)

      # This could be a better solution as it does not require to load the content query into memory.
      # Unfortunetaly, Repo.stream/1 does not allow preloads. You would need to map the data structure yourself.
      #
      # query = from(Brainstorming, preload: [:labels])
      # stream = Repo.stream(query)
      # Repo.transaction(fn() ->
      #   Enum.each(stream, &migrate_labels_to_idea_labels/1)
      # end)
    end)
  end

  def migrate_labels_from_ideas do
    Repo.transaction(fn ->
      from(Idea,
        preload: [:label, brainstorming: [:labels]],
        select: [:deprecated_label, :brainstorming_id, :label_id, :id]
      )
      |> Repo.all()
      |> Enum.each(&migrate_label_to_idea_label/1)
    end)
  end

  def deprecated_label_to_idea_label_name_for(deprecated_label) do
    @deprecated_label_to_idea_label_name_mapping[deprecated_label]
  end

  def deprecated_label_to_idea_label_name_mapping,
    do: @deprecated_label_to_idea_label_name_mapping

  defp migrate_labels_to_idea_labels(%Brainstorming{} = brainstorming) do
    new_labels = (brainstorming.labels ++ Brainstorming.idea_label_factory()) |> Enum.slice(0..4)

    change(brainstorming)
    |> put_assoc(:labels, new_labels)
    |> Repo.update()
  end

  defp migrate_label_to_idea_label(%Idea{} = idea) do
    unless idea.label do
      idea_label_name = deprecated_label_to_idea_label_name_for(idea.deprecated_label)

      idea_label =
        Enum.find(idea.brainstorming.labels, fn idea_label ->
          idea_label.name == idea_label_name
        end)

      change(idea)
      |> put_assoc(:label, idea_label)
      |> Repo.update()
    end
  end
end
