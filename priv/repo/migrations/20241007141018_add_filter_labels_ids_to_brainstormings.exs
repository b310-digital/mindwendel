defmodule Mindwendel.Repo.Migrations.AddFilterLabelsIdsToBrainstormings do
  use Ecto.Migration

  def change do
    alter table(:brainstormings) do
      add(:filter_labels_ids, {:array, :uuid}, default: [])
    end
  end
end
