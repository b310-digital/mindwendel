defmodule Mindwendel.Repo.Migrations.AddBrainstormingReferenceToIdeas do
  use Ecto.Migration

  def change do
    alter table(:ideas) do
      add :brainstorming_id, references(:brainstormings, type: :uuid)
    end
  end
end
