defmodule Mindwendel.Repo.Migrations.AddDefaultPositionOrderForIdeas do
  use Ecto.Migration

  Code.require_file(
    "#{:code.priv_dir(:mindwendel)}/repo/data_migrations/migrate_add_position_order_to_ideas.exs"
  )

  def change do
    Mindwendel.Repo.DataMigrations.MigrateAddPositionOrderToIdeas.run()
  end
end
