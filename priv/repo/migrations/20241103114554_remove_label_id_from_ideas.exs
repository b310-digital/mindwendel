defmodule Mindwendel.Repo.Migrations.RemoveLabelIdFromIdeas do
  use Ecto.Migration

  def change do
    alter table(:ideas) do
      remove :label_id, references(:idea_labels, type: :uuid)
    end
  end
end
