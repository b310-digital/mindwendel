defmodule Mindwendel.Repo.Migrations.CreateIdeas do
  use Ecto.Migration

  def change do
    create table(:ideas) do
      add :username, :string
      add :body, :string
      add :like_count, :integer
      add :dislike_count, :integer

      timestamps()
    end
  end
end
