defmodule Mindwendel.Repo.DataMigrations.MigrateIdeaLabelsToIdeaIdeaLabels do
  require Logger

  def run do
    try do
      Ecto.Adapters.SQL.query!(Mindwendel.Repo, migration_sql())
    rescue
      e in Postgrex.Error ->
        Logger.error("""
        An error occured when executing the migration script.
        Please ensure the table idea_idea_labels is created and empty before executing this migration
        script.
        """)

        Logger.error(Exception.format(:error, e, __STACKTRACE__))

        reraise e, __STACKTRACE__
    end
  end

  defp migration_sql do
    """
    INSERT INTO idea_idea_labels (idea_id, idea_label_id, inserted_at, updated_at)
    (
      SELECT id, label_id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM ideas
      WHERE label_id IS NOT NULL
    );
    """
  end
end
