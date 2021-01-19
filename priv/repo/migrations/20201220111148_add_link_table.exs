defmodule Mindwendel.Repo.Migrations.AddLinkTable do
  use Ecto.Migration

  def change do
    create table(:links) do
      add :url, :text
      add :title, :text
      add :description, :text
      add :img_preview_url, :text
      add :idea_id, references(:ideas)

      timestamps()
    end
  end
end
