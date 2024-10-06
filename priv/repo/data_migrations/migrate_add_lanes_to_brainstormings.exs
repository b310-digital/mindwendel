defmodule Mindwendel.Repo.DataMigrations.MigrateAddLanesToBrainstormings do
  require Logger

  def run do
    try do
      Ecto.Adapters.SQL.query!(Mindwendel.Repo, migration_add_lanes_sql())
      Ecto.Adapters.SQL.query!(Mindwendel.Repo, migrate_update_ideas_with_lane_sql())
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

  defp migration_add_lanes_sql do
    """
    INSERT INTO lanes (id, position_order, brainstorming_id, inserted_at, updated_at)
    (
      SELECT gen_random_uuid(), 1, id, NOW(), NOW()
      FROM brainstormings
    );
    """
  end

  defp migrate_update_ideas_with_lane_sql do
    """
    UPDATE ideas SET lane_id = lanes.id FROM
    (
      SELECT id, brainstorming_id
      FROM lanes
    ) as lanes
    WHERE ideas.brainstorming_id = lanes.brainstorming_id;
    """
  end
end
