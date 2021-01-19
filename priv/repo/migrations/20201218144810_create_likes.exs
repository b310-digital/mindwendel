defmodule Mindwendel.Repo.Migrations.CreateLikes do
  use Ecto.Migration

  def change do
    create table(:likes) do
      add :idea_id, references(:ideas, on_delete: :nothing)

      timestamps()
    end

    create index(:likes, [:idea_id])
  end
end
