defmodule Mindwendel.Repo.Migrations.AddLabelIdToIdeas do
  use Ecto.Migration

  def change do
    alter table("ideas") do
      add :label_id, references(:idea_labels, type: :uuid)
    end
  end
end
