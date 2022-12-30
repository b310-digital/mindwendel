defmodule Mindwendel.Repo.Migrations.AddCreatingUserIdToBrainstormings do
  use Ecto.Migration

  def change do
    alter table("brainstormings") do
      add :creating_user_id, references(:users, type: :uuid)
    end
  end
end
