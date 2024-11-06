defmodule Mindwendel.Repo.Migrations.CreateIdeaFiles do
  use Ecto.Migration

  def change do
    create table(:idea_files, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :path, :string
      add :name, :string
      add :file_type, :string
      add :idea_id, references(:ideas, type: :uuid, on_delete: :nilify_all)

      timestamps()
    end
  end
end
