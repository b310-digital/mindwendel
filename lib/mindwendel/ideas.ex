defmodule Mindwendel.Ideas do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Lanes
  alias Mindwendel.Attachments
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Brainstormings.Idea

  require Logger

  @doc """
  Returns the max position order for either ideas and given labels or a lane

  ## Examples

      iex> get_max_position_order(123, %{labels_ids: [467]})
      3

      iex> get_max_position_order(123, %{lane_id: 1})
      2


  """
  def get_max_position_order(brainstorming_id, %{labels_ids: labels_ids}) do
    idea_query =
      from idea in Idea,
        left_join: l in assoc(idea, :idea_labels),
        where: idea.brainstorming_id == ^brainstorming_id and l.id in ^labels_ids

    Repo.aggregate(idea_query, :max, :position_order) || 0
  end

  def get_max_position_order(brainstorming_id, %{lane_id: lane_id}) do
    idea_query =
      from idea in Idea,
        where:
          idea.brainstorming_id == ^brainstorming_id and idea.lane_id == ^lane_id and
            not is_nil(idea.position_order)

    Repo.aggregate(idea_query, :max, :position_order) || 0
  end

  @doc """
  Returns the list of ideas.

  ## Examples

      iex> list_ideas()
      [%Idea{}, ...]

  """
  def list_ideas do
    Repo.all(Idea)
  end

  @doc """
  Returns the list of ideas depending on the brainstorming id and lane id, ordered by position.

  ## Examples

      iex> list_ideas(3, 1)
      [%Idea{}, ...]

  """
  def list_ideas_for_brainstorming(id) do
    idea_count_query =
      from like in Like,
        group_by: like.idea_id,
        select: %{idea_id: like.idea_id, like_count: count(1)}

    idea_query =
      from idea in Idea,
        left_join: idea_count in subquery(idea_count_query),
        on: idea_count.idea_id == idea.id,
        where: idea.brainstorming_id == ^id,
        order_by: [
          asc_nulls_last: idea.position_order,
          asc: idea.inserted_at
        ]

    Repo.all(idea_query)
    |> Repo.preload([
      :link,
      :likes,
      :idea_labels,
      :comments
    ])
  end

  @doc """
  Returns the update result of sorting and updating ideas by likes inside a brainstorming.

  ## Examples

      iex> update_ideas_for_brainstorming_by_likes(3)
      %{1, nil}

  """
  def update_ideas_for_brainstorming_by_likes(brainstorming_id, lane_id) do
    idea_count_query =
      from like in Like,
        group_by: like.idea_id,
        select: %{idea_id: like.idea_id, like_count: count(1)}

    # get the rank for all ideas and left join to get missing ideas without likes
    idea_rank_query =
      from(idea in Idea,
        left_join: idea_counts in subquery(idea_count_query),
        on: idea_counts.idea_id == idea.id,
        where: idea.brainstorming_id == ^brainstorming_id and idea.lane_id == ^lane_id,
        select: %{
          idea_id: idea.id,
          like_count: idea_counts.like_count,
          idea_rank: over(row_number(), order_by: [desc_nulls_last: idea_counts.like_count])
        }
      )

    # update all ideas with their rank
    from(idea in Idea,
      join: idea_ranks in subquery(idea_rank_query),
      on: idea_ranks.idea_id == idea.id,
      where: idea.brainstorming_id == ^brainstorming_id and idea.lane_id == ^lane_id,
      update: [set: [position_order: idea_ranks.idea_rank]]
    )
    |> Repo.update_all([])

    Lanes.broadcast_lanes_update(brainstorming_id)
  end

  @doc """
  Returns the update result of sorting and updating ideas by labels inside a brainstorming.

  ## Examples

      iex> update_ideas_for_brainstorming_by_labels(3)
      %{1, nil}

  """
  def update_ideas_for_brainstorming_by_labels(brainstorming_id, lane_id) do
    idea_rank_query =
      from(idea in Idea,
        left_join: l in assoc(idea, :idea_labels),
        where: idea.brainstorming_id == ^brainstorming_id and idea.lane_id == ^lane_id,
        select: %{
          idea_id: idea.id,
          idea_rank:
            over(row_number(),
              order_by: [asc_nulls_last: l.position_order, desc: idea.inserted_at]
            )
        }
      )

    # update all ideas with their rank
    from(idea in Idea,
      join: idea_ranks in subquery(idea_rank_query),
      on: idea_ranks.idea_id == idea.id,
      where: idea.brainstorming_id == ^brainstorming_id and idea.lane_id == ^lane_id,
      update: [set: [position_order: idea_ranks.idea_rank]]
    )
    |> Repo.update_all([])

    Lanes.broadcast_lanes_update(brainstorming_id)
  end

  @doc """
  Reorders the positions of disjoint (hidden) ideas based on the current label filter.
  This is triggered before a label filter is applied, ensuring hidden ideas are placed
  after visible ones. Without this adjustment, deactivating the filter would result
  in mixed or shuffled positions due to outdated order information.

  Example: If a filter for "blue" ideas (b1, b2, b3) is applied, and "red" ideas
  (r4, r5, r6) are hidden, this function updates the red ideas' positions to follow
  the blue ones (positions 4, 5, 6). When the filter is removed, the correct
  sequence is maintained.

  ## Examples

      iex> update_disjoint_idea_positions_for_brainstorming_by_labels(3, [1,2,3])
      %{1, nil}

  """
  def update_disjoint_idea_positions_for_brainstorming_by_labels(
        brainstorming_id,
        labels_ids
      ) do
    max_position_order = get_max_position_order(brainstorming_id, %{labels_ids: labels_ids})

    # Get all idea ids that are matching the given labels.
    ideas_with_labels =
      from(idea in Idea,
        join: l in assoc(idea, :idea_labels),
        where: idea.brainstorming_id == ^brainstorming_id and l.id in ^labels_ids,
        distinct: idea.id,
        select: %{id: idea.id}
      )

    # Use the disjoint ideas and order them starting with the max position order of the matched ideas with labels.
    idea_rank_query =
      from(idea in Idea,
        where:
          idea.brainstorming_id == ^brainstorming_id and
            idea.id not in subquery(ideas_with_labels),
        select: %{
          idea_id: idea.id,
          idea_rank:
            over(row_number(),
              order_by: [asc_nulls_last: idea.position_order]
            )
        }
      )

    # update all ideas with their rank
    from(idea in Idea,
      join: idea_ranks in subquery(idea_rank_query),
      on: idea_ranks.idea_id == idea.id,
      where: idea.brainstorming_id == ^brainstorming_id,
      update: [set: [position_order: idea_ranks.idea_rank + ^max_position_order]]
    )
    |> Repo.update_all([])
  end

  @doc """
  Returns the update result of changing the order of ideas by a user inside a brainstorming.

  ## Examples

      iex> update_ideas_for_brainstorming_by_user_move(3, 1, 1, 3)
      %{1, nil}

  """
  def update_ideas_for_brainstorming_by_user_move(
        brainstorming_id,
        lane_id,
        idea_id,
        new_position,
        old_position
      ) do
    get_idea!(idea_id) |> update_idea(%{position_order: new_position, lane_id: lane_id})

    # depending on moving a card bottom up or up to bottom, we need to correct the ordering
    order =
      if new_position <= old_position,
        do: [asc: :position_order, desc: :updated_at],
        else: [asc: :position_order, asc: :updated_at]

    idea_rank_query =
      from(idea in Idea,
        where: idea.brainstorming_id == ^brainstorming_id and idea.lane_id == ^lane_id,
        windows: [o: [order_by: ^order]],
        select: %{
          idea_id: idea.id,
          idea_rank: over(row_number(), :o)
        }
      )

    from(idea in Idea,
      join: idea_ranks in subquery(idea_rank_query),
      on: idea_ranks.idea_id == idea.id,
      where: idea.brainstorming_id == ^brainstorming_id,
      update: [set: [position_order: idea_ranks.idea_rank]]
    )
    |> Repo.update_all([])

    Lanes.broadcast_lanes_update(brainstorming_id)
  end

  @doc """
  Gets a single idea.

  Raises `Ecto.NoResultsError` if the Idea does not exist.

  ## Examples

      iex> get_idea!(123)
      %Idea{}

      iex> get_idea!(456)
      ** (Ecto.NoResultsError)

  """
  def get_idea!(id),
    do: Repo.get!(Idea, id) |> Repo.preload([:idea_labels, :files, :link, :comments])

  @doc """
  Creates a idea.

  ## Examples

      iex> create_idea(%{field: value})
      {:ok, %Idea{}}

      iex> create_idea(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_idea(attrs \\ %{}) do
    %Idea{}
    |> Idea.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, idea} ->
        scan_for_link_in_idea(idea)
        Lanes.broadcast_lanes_update(idea.brainstorming_id)
        {:ok, idea}

      {_, result} ->
        {:error, result}
    end
  end

  @doc """
  Scans for links in the idea body and adds a link entity if present.

  ## Examples

      iex> scan_for_link_in_idea(idea)
      {:ok, idea}

  """
  def scan_for_link_in_idea(idea) do
    Task.start(fn ->
      Repo.preload(idea, :link)
      |> Idea.build_link()
      |> Repo.update()

      Lanes.broadcast_lanes_update(idea.brainstorming_id)
    end)

    {:ok, idea}
  end

  @doc """
  Updates a idea.

  ## Examples

      iex> update_idea(idea, %{field: new_value})
      {:ok, %Idea{}}

      iex> update_idea(idea, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_idea(%Idea{} = idea, attrs) do
    result =
      idea
      |> Idea.changeset(attrs)
      |> Repo.update()

    Lanes.broadcast_lanes_update(idea.brainstorming_id)
    result
  end

  @doc """
  Increments the comment count of an idea.

  ## Examples

      iex> increment_comment_count(idea_id)
      {:ok, %Idea{}}

      iex> increment_comment_count(idea_id)
      {:error, %Ecto.Changeset{}}

  """
  def increment_comment_count(idea_id) do
    idea = Repo.get!(Idea, idea_id)
    changeset = Idea.changeset(idea, %{comments_count: idea.comments_count + 1})
    Repo.update(changeset)
  end

  @doc """
  Decrements the comment count of an idea.

  ## Examples

      iex> decrement_comment_count(idea_id)
      {:ok, %Idea{}}

      iex> decrement_comment_count(idea_id)
      {:error, %Ecto.Changeset{}}

  """
  def decrement_comment_count(idea_id) do
    idea = Repo.get!(Idea, idea_id)

    new_comments_count =
      if idea.comments_count - 1 >= 0 do
        idea.comments_count - 1
      else
        0
      end

    changeset = Idea.changeset(idea, %{comments_count: new_comments_count})
    Repo.update(changeset)
  end

  @doc """
  Deletes a idea.

  ## Examples

      iex> delete_idea(idea)
      {:ok, %Idea{}}

      iex> delete_idea(idea)
      {:error, %Ecto.Changeset{}}

  """
  def delete_idea(%Idea{} = idea) do
    {:ok, _} = delete_files(idea)
    Repo.delete(idea)
    Lanes.broadcast_lanes_update(idea.brainstorming_id)
  end

  defp delete_files(%Idea{} = idea) do
    files = Repo.preload(idea, :files).files
    result = Enum.map(files, fn file -> Attachments.delete_attached_file(file) end)
    {:ok, result}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking idea changes.

  ## Examples

      iex> change_idea(idea)
      %Ecto.Changeset{data: %Idea{}}

  """
  def change_idea(%Idea{} = idea, attrs \\ %{}) do
    Repo.preload(idea, [:link, :idea_labels, :comments, :files]) |> Idea.changeset(attrs)
  end
end
