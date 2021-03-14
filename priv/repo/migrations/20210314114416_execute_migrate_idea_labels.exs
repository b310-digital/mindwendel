defmodule Mindwendel.Repo.Migrations.ExecuteMigrateIdeaLabels do
  Code.require_file("./priv/repo/data_migrations/migrate_idea_labels.exs")

  use Ecto.Migration

  def up do
    Mindwendel.Repo.DataMigrations.MigrateIdealLabels.run()
  end

  # We do nothing here
  def down, do: nil
end
