defmodule Mindwendel.Repo.Migrations.AddFilterActiveToIdeaLabels do
  use Ecto.Migration

  def change do
    alter table(:idea_labels) do
      add(:filter_active, :boolean, default: true)
    end
  end
end
