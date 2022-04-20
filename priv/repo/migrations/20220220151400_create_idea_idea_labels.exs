defmodule Mindwendel.Repo.Migrations.CreateIdeaIdeaLabels do
  use Ecto.Migration

  def change do
    create table(:idea_idea_labels, primary_key: false) do
      add(:idea_id, references(:ideas, type: :uuid, on_delete: :delete_all), primary_key: true)

      add(:idea_label_id, references(:idea_labels, type: :uuid), primary_key: true)

      timestamps()
    end

    create(index(:idea_idea_labels, [:idea_id]))
    create(index(:idea_idea_labels, [:idea_label_id]))

    create(unique_index(:idea_idea_labels, [:idea_id, :idea_label_id]))
  end
end
