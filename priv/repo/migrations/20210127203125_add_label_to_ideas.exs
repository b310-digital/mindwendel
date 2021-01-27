defmodule Mindwendel.Repo.Migrations.AddLabelToIdeas do
  use Ecto.Migration

  def change do
    alter table("ideas") do
      add :label, :text
    end
  end
end
