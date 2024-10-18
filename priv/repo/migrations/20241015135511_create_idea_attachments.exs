defmodule Mindwendel.Repo.Migrations.CreateIdeaAttachments do
  use Ecto.Migration

  def change do
    create table(:idea_attachments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :path, :string
      add :name, :string
      add :idea_id, references(:ideas, type: :uuid, on_delete: :delete_all)

      timestamps()
    end
  end
end
