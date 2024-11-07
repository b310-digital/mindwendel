defmodule Mindwendel.Repo.Migrations.AddCommentsForIdeas do
  use Ecto.Migration

  def change do
    create table(:idea_comments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :comment_text, :string, size: 500
      # same as the user table, however, the ideas table allows longer names
      add :username, :string, size: 64
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)
      add :idea_id, references(:ideas, type: :uuid, on_delete: :nilify_all)

      timestamps()
    end

    alter table(:ideas) do
      add(:comments_count, :integer, default: 0)
    end
  end
end
