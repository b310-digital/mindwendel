defmodule Mindwendel.Repo.Migrations.AddMigrationToAddLanesToOldBrainstormings do
  use Ecto.Migration

  Code.require_file(
    "#{:code.priv_dir(:mindwendel)}/repo/data_migrations/migrate_add_lanes_to_brainstormings.exs"
  )

  def change do
    Mindwendel.Repo.DataMigrations.MigrateAddLanesToBrainstormings.run()
  end
end
