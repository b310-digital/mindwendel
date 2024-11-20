defmodule Mindwendel.Repo.Migrations.MigrateIdeaLabelsToIdeaIdeaLabels do
  use Ecto.Migration

  # There used to be code here, but the migration is so old it's not worth keeping significant code
  # and its tests around. No one needs a 2 year+ old data migration, or so I hope.
  # However, the migration already ran/is saved in the `schema_migrations` so removing it would also
  # be confusing. Hence, it's kept empty.
  def up do
  end

  # We do nothing here
  def down, do: nil
end
