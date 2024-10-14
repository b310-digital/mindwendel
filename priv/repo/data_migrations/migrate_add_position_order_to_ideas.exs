defmodule Mindwendel.Repo.DataMigrations.MigrateAddPositionOrderToIdeas do
  require Logger
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Brainstorming
  import Ecto.Query, warn: false

  def run do
    idea_query = from(idea in Idea,
                   where: is_nil(idea.position_order),
                   distinct: idea.brainstorming_id
                 )
    brainstormings = Repo.all(from(brainstorming in Brainstorming, join: ideas_without_pos_number in subquery(idea_query), on: ideas_without_pos_number.brainstorming_id == brainstorming.id))
    Enum.map(brainstormings, fn brainstorming -> update_position_order(brainstorming.id) end)
  end

  defp update_position_order(brainstorming_id) do
    idea_rank_query =
      from(idea in Idea,
        where:
          idea.brainstorming_id == ^brainstorming_id,
        select: %{
          idea_id: idea.id,
          idea_rank:
            over(row_number(),
              order_by: [asc_nulls_last: idea.position_order, asc: idea.inserted_at]
            )
        }
      )

    from(idea in Idea,
      join: idea_ranks in subquery(idea_rank_query),
      on: idea_ranks.idea_id == idea.id,
      where: idea.brainstorming_id == ^brainstorming_id,
      update: [set: [position_order: idea_ranks.idea_rank]]
    )
    |> Repo.update_all([])
  end
end
