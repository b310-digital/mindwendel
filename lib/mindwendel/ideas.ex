defmodule Mindwendel.Ideas do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Brainstormings.Idea

  require Logger

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
  Returns the list of ideas depending on the brainstorming id.

  ## Examples

      iex> list_ideas(3)
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
        order_by: [desc_nulls_last: idea_count.like_count, desc: idea.inserted_at]

    Repo.all(idea_query)
    |> Repo.preload([
      :link,
      :likes,
      :label,
      :idea_labels
    ])
  end

  def sort_ideas_by_labels(brainstorming_id) do
    from(
      idea in Idea,
      left_join: l in assoc(idea, :idea_labels),
      where: idea.brainstorming_id == ^brainstorming_id,
      preload: [
        :link,
        :likes,
        :idea_labels
      ],
      order_by: [
        asc_nulls_last: l.position_order,
        desc: idea.inserted_at
      ]
    )
    |> Repo.all()
    |> Enum.uniq()
  end

  def sort_ideas_by_order_position(brainstorming_id) do
    from(
      idea in Idea,
      where: idea.brainstorming_id == ^brainstorming_id,
      preload: [
        :link,
        :likes,
        :label,
        :idea_labels
      ],
      order_by: [
        asc: idea.order_position
      ]
    )
    |> Repo.all()
    |> Repo.preload([
      :link,
      :likes,
      :label,
      :idea_labels
    ])
  end

  def update_ideas_for_brainstorming_by_likes(id) do
    idea_count_query =
      from like in Like,
        group_by: like.idea_id,
        select: %{idea_id: like.idea_id, like_count: count(1)}

    # get the rank for all ideas and left join to get missing ideas without likes
    idea_rank_query =
      from(idea in Idea,
        left_join: idea_counts in subquery(idea_count_query),
        on: idea_counts.idea_id == idea.id,
        where: idea.brainstorming_id == ^id,
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
      where: idea.brainstorming_id == ^id,
      update: [set: [order_position: idea_ranks.idea_rank]]
    )
    |> Repo.update_all([])
  end

  def update_ideas_for_brainstorming_by_labels(id) do
    idea_rank_query =
      from(idea in Idea,
        left_join: l in assoc(idea, :idea_labels),
        where: idea.brainstorming_id == ^id,
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
      where: idea.brainstorming_id == ^id,
      update: [set: [order_position: idea_ranks.idea_rank]]
    )
    |> Repo.update_all([])
  end

  def update_ideas_for_brainstorming_by_user_move(
        brainstorming_id,
        idea_id,
        new_position,
        old_position
      ) do
    get_idea!(idea_id) |> update_idea(%{order_position: new_position})

    # depending on moving a card bottom up or up to bottom, we need to correct the ordering
    order =
      if new_position < old_position,
        do: [asc: :order_position, desc: :updated_at],
        else: [asc: :order_position, asc: :updated_at]

    idea_rank_query =
      from(idea in Idea,
        where: idea.brainstorming_id == ^brainstorming_id,
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
      update: [set: [order_position: idea_ranks.idea_rank]]
    )
    |> Repo.update_all([])
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
  def get_idea!(id), do: Repo.get!(Idea, id) |> Repo.preload([:label, :idea_labels])

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
      {:ok, result} -> scan_for_link_in_idea(result)
      {_, result} -> {:error, result}
    end
    |> Brainstormings.broadcast(:idea_added)
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
      |> Brainstormings.broadcast(:idea_updated)
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
    idea
    |> Idea.changeset(attrs)
    |> Repo.update()
    |> Brainstormings.broadcast(:idea_updated)
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
    Repo.delete(idea)
    Brainstormings.broadcast({:ok, idea}, :idea_removed)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking idea changes.

  ## Examples

      iex> change_idea(idea)
      %Ecto.Changeset{data: %Idea{}}

  """
  def change_idea(%Idea{} = idea, attrs \\ %{}) do
    Repo.preload(idea, [:link, :idea_labels]) |> Idea.changeset(attrs)
  end
end
