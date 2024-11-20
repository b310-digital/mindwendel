defmodule Mindwendel.Repo.Migrations.RemoveUnusedLabelFields do
  use Ecto.Migration

  def change do
    alter table(:ideas) do
      remove :label, :text
      remove :label_id, references(:idea_labels, type: :uuid)
    end
  end
end
