defmodule Mindwendel.Repo.Migrations.ChangeIdFieldOnIdeas do
  use Ecto.Migration

  def up do
    execute "drop table ideas CASCADE;"
    execute "drop table likes CASCADE;"
    execute "drop table links CASCADE;"

    create table(:ideas, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :username, :string
      add :brainstorming_id, references(:brainstormings, type: :uuid, on_delete: :delete_all)
      add :body, :string, size: 1024
      timestamps()
    end

    create table(:likes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :idea_id, references(:ideas, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    create table(:links, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :url, :text
      add :title, :text
      add :description, :text
      add :img_preview_url, :text
      add :idea_id, references(:ideas, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    create index(:likes, [:idea_id])
  end

  def down do
    execute "drop table ideas CASCADE;"
    execute "drop table likes CASCADE;"
    execute "drop table links CASCADE;"

    create table(:ideas) do
      add :username, :string
      add :body, :string
      add :like_count, :integer
      add :dislike_count, :integer
      add :brainstorming_id, references(:brainstormings, type: :uuid)
      timestamps()
    end

    create table(:likes) do
      add :idea_id, references(:ideas, on_delete: :delete_all)

      timestamps()
    end

    create table(:links) do
      add :url, :text
      add :title, :text
      add :description, :text
      add :img_preview_url, :text
      add :idea_id, references(:ideas, on_delete: :delete_all)

      timestamps()
    end

    create index(:likes, [:idea_id])
  end
end
