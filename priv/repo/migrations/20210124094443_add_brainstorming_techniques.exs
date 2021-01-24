defmodule Mindwendel.Repo.Migrations.AddBrainstormingTechniques do
  use Ecto.Migration

  def change do
    create table(:brainstorming_techniques, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, size: 64
      add :language, :string, size: 4
      add :description, :string, size: 1024

      timestamps()
    end
    create unique_index(:brainstorming_techniques, [:title])
  end
end
