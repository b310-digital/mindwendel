defmodule Mindwendel.Repo.Migrations.AddUserIdToIdeas do
  use Ecto.Migration

  def change do
    alter table("ideas") do
      add :user_id, references(:users, type: :uuid, on_delete: :nilify_all)
    end
  end
end
