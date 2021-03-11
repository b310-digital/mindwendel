defmodule Mindwendel.Repo.DataMigrations.MigrateIdealLabels do
  import Ecto.Query
  import Ecto.Changeset
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaLabel

  @label_old_to_idea_label_name_mapping %{
    label_1: "cyan",
    label_2: "gray-dark",
    label_3: "green",
    label_4: "red",
    label_5: "yellow"
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
      from(Idea, preload: [:label, brainstorming: [:labels]])
      |> Repo.all()
      |> Enum.each(&migrate_label_to_idea_label/1)
    end)
  end

  def label_old_to_idea_label_name_for(label_old) do
    @label_old_to_idea_label_name_mapping[label_old]
  end

  def label_old_to_idea_label_name_mapping, do: @label_old_to_idea_label_name_mapping

  defp migrate_labels_to_idea_labels(%Brainstorming{} = brainstorming) do
    new_labels = (brainstorming.labels ++ Brainstorming.idea_label_factory()) |> Enum.slice(0..4)

    change(brainstorming)
    |> put_assoc(:labels, new_labels)
    |> Repo.update()
  end

  defp migrate_label_to_idea_label(%Idea{} = idea) do
    unless idea.label do
      idea_label_name = label_old_to_idea_label_name_for(idea.label_old)

      idea_label =
        Enum.find(idea.brainstorming.labels, fn idea_label ->
          idea_label.name == idea_label_name
        end)

      # change(idea, %{label_id: idea_label.id})
      change(idea)
      |> put_assoc(:label, idea_label)
      |> Repo.update()
    end
  end
end