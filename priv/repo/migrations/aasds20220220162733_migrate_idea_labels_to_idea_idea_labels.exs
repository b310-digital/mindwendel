defmodule Mindwendel.Repo.Migrations.MigrateIdeaLabelsToIdeaIdeaLabels do
  # Remember to always use a relative file to the priv directory of the elixir app.
  # Therefore, we are using `:code.priv_dir(:mindwendel)`
  # See https://elixirforum.com/t/handling-relative-paths-inside-my-mix-project/28974
  Code.require_file(
    "#{:code.priv_dir(:mindwendel)}/repo/data_migrations/migrate_idea_labels_to_idea_idea_labels.exs"
  )

  use Ecto.Migration

  def up do
    Mindwendel.Repo.DataMigrations.MigrateIdeaLabelsToIdeaIdeaLabels.run()
  end

  # We do nothing here
  def down, do: nil
end
