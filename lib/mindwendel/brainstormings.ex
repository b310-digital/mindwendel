defmodule Mindwendel.Brainstormings do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.BrainstormingModeratingUser
  alias Mindwendel.Brainstormings.Like

  require Logger

  @doc """
  Returns the 3 most recent brainstormings for a a user.

  ## Examples

      iex> list_brainstormings_for(3)
      [%Brainstorming{}, ...]

  """
  def list_brainstormings_for(user_id, limit \\ 3) do
    Repo.all(
      from brainstorming in Brainstorming,
        join: users in assoc(brainstorming, :users),
        where: users.id == ^user_id,
        order_by: [desc: brainstorming.inserted_at],
        limit: ^limit
    )
  end

  def add_moderating_user(%Brainstorming{} = brainstorming, %User{} = user) do
    %BrainstormingModeratingUser{brainstorming_id: brainstorming.id, user_id: user.id}
    |> BrainstormingModeratingUser.changeset()
    |> Repo.insert()
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
  Count likes for an idea.

  ## Examples

      iex> count_likes_for_idea(idea)
      5

  """
  def count_likes_for_idea(idea), do: idea |> Ecto.assoc(:likes) |> Repo.aggregate(:count, :id)

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
    |> broadcast(:idea_added)
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
      |> broadcast(:idea_updated)
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
    |> broadcast(:idea_updated)
  end

  def update_idea_label(%Idea{} = idea, label) do
    idea
    |> Idea.changeset_update_label(label)
    |> Repo.update()
    |> broadcast(:idea_updated)
  end

  def add_idea_label_to_idea(%Idea{} = idea, %IdeaLabel{} = idea_label) do
    idea = Repo.preload(idea, :idea_labels)

    idea_labels =
      (idea.idea_labels ++ [idea_label])
      |> Enum.map(&Ecto.Changeset.change/1)

    idea
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:idea_labels, idea_labels)
    |> Repo.update()
    |> broadcast(:idea_updated)
  end

  def remove_idea_label_from_idea(%Idea{} = idea, %IdeaLabel{} = idea_label) do
    from(idea_idea_label in IdeaIdeaLabel,
      where:
        idea_idea_label.idea_id == ^idea.id and
          idea_idea_label.idea_label_id == ^idea_label.id
    )
    |> Repo.delete_all()

    {:ok, get_idea!(idea.id)} |> broadcast(:idea_updated)
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
    broadcast({:ok, idea}, :idea_removed)
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

  @doc """
  Returns the list of brainstormings.

  ## Examples

      iex> list_brainstormings()
      [%Brainstorming{}, ...]

  """
  def list_brainstormings do
    Repo.all(Brainstorming)
  end

  @doc """
  Gets a single brainstorming.

  Raises `Ecto.NoResultsError` if the Brainstorming does not exist.

  ## Examples

      iex> get_brainstorming!("0323906b-b496-4778-ae67-1dd779d3de3c")
      %Brainstorming{ ... }

      iex> get_brainstorming!("0323906b-b496-4778-ae67-1dd779d3de3c")
      ** (Ecto.NoResultsError)

      iex> get_brainstorming!("not_a_valid_uuid_string")
      ** (Ecto.Query.CastError)

  """
  # See https://stackoverflow.com/questions/53802091/elixir-uuid-how-to-handle-500-error-when-uuid-doesnt-match
  def get_brainstorming!(id) do
    Repo.get!(Brainstorming, id)
    |> Repo.preload([
      :users,
      :moderating_users,
      labels: from(idea_label in IdeaLabel, order_by: idea_label.position_order),
      ideas: [
        :link,
        :likes,
        :label,
        :idea_labels
      ]
    ])
  end

  @doc """
  Gets a single brainstorming with the admin url id
  """
  def get_brainstorming_by!(%{admin_url_id: admin_url_id}) do
    Repo.get_by!(Brainstorming, admin_url_id: admin_url_id)
  end

  def get_idea_label!(id) do
    Repo.get!(IdeaLabel, id)
  end

  def get_idea_label(id) when not is_nil(id) do
    Repo.get(IdeaLabel, id)
  rescue
    Ecto.Query.CastError -> nil
  end

  def get_idea_label(id) when is_nil(id) do
    nil
  end

  @doc """
  Creates a brainstorming and associates a user as creating_user, moderatoring user (also called brainstorming admin) and user.

  User hast to be persisted.

  ## Examples

    current_user =
        MindwendelService.SessionService.get_current_user_id(conn)
        |> Accounts.get_or_create_user()

    {:ok, %Brainstorming{ ... }} =
      Brainstormings.create_brainstorming(current_user, %{name: "Brainstorming name"})

  """
  def create_brainstorming(%User{} = user, attrs) do
    user
    |> Ecto.build_assoc(:created_brainstormings,
      labels: Brainstorming.idea_label_factory(),
      moderating_users: [user],
      users: [user]
    )
    |> Brainstorming.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a brainstorming.

  ## Examples

      iex> update_brainstorming(brainstorming, %{field: new_value})
      {:ok, %Brainstorming{}}

      iex> update_brainstorming(brainstorming, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_brainstorming(%Brainstorming{} = brainstorming, attrs) do
    brainstorming
    |> Brainstorming.changeset(attrs)
    |> Repo.update()
    |> broadcast(:brainstorming_updated)
  end

  @doc """
  Deletes a brainstorming.

  ## Examples

      iex> delete_brainstorming(brainstorming)
      {:ok, %Brainstorming{}}

      iex> delete_brainstorming(brainstorming)
      {:error, %Ecto.Changeset{}}

  """
  def delete_brainstorming(%Brainstorming{} = brainstorming) do
    Repo.transaction(fn ->
      Repo.delete_all(from idea in Idea, where: idea.brainstorming_id == ^brainstorming.id)
      Repo.delete(brainstorming)
    end)
  end

  @doc """
  Deletes all brainstormings, older than 30 days since creation

  ## Examples

      iex> delete_old_brainstormings(30)
      :ok

  """
  def delete_old_brainstormings(after_days \\ 30) do
    date_time = Timex.now() |> Timex.shift(days: -1 * after_days)
    brainstormings_count = Repo.aggregate(Brainstorming, :count, :id)

    old_brainstormings_query = from b in Brainstorming, where: b.inserted_at < ^date_time
    old_brainstormings_count = Repo.aggregate(old_brainstormings_query, :count, :id)

    Logger.info(
      "Delete old brainstormings. Count: #{old_brainstormings_count} / #{brainstormings_count}"
    )

    Logger.info("Starting to delete old brainstormings:")
    brainstormings = Repo.all(old_brainstormings_query)

    Enum.each(brainstormings, fn brainstorming ->
      try do
        delete_brainstorming(brainstorming)
      rescue
        e in RuntimeError ->
          Logger.error("Error while deleting brainstorming: #{brainstorming.id}")
          Logger.error(e)
      end
    end)

    Logger.info("Finished deleting old brainstormings")
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking brainstorming changes.

  ## Examples

      iex> change_brainstorming(brainstorming)
      %Ecto.Changeset{data: %Brainstorming{}}

  """
  def change_brainstorming(%Brainstorming{} = brainstorming, attrs \\ %{}) do
    Brainstorming.changeset(brainstorming, attrs)
  end

  @doc """
  Returns a Boolean if a like for the given idea and user exists.

  ## Examples

      iex> exists_like_for_idea?(1, 2)
      true

  """
  def exists_like_for_idea?(idea_id, user_id) do
    Repo.exists?(from like in Like, where: like.user_id == ^user_id and like.idea_id == ^idea_id)
  end

  @doc """
  Returns a broadcast tuple of the idea update.

  ## Examples

      iex> add_like(1, 2)
      {:ok, %Idea{}}

  """
  def add_like(idea_id, user_id) do
    {status, result} =
      %Like{}
      |> Like.changeset(%{idea_id: idea_id, user_id: user_id})
      |> Repo.insert()

    case status do
      :ok -> {:ok, get_idea!(idea_id)} |> broadcast(:idea_updated)
      :error -> {:error, result}
    end
  end

  @doc """
  Deletes a like for an idea by a given user

  ## Examples

      iex> delete_like(1, 2)
      {:ok, %Idea{}}

  """
  def delete_like(idea_id, user_id) do
    # we ignore the result, delete_all returns the count of deleted items. We'll reload and broadcast the idea either way:
    Repo.delete_all(
      from like in Like, where: like.user_id == ^user_id and like.idea_id == ^idea_id
    )

    {:ok, get_idea!(idea_id)} |> broadcast(:idea_updated)
  end

  @doc """
  Returns a subscibe result.

  ## Examples

      iex> subscribe(3)
      :ok

  """
  def subscribe(brainstorming_id) do
    Phoenix.PubSub.subscribe(
      Mindwendel.PubSub,
      "brainstormings:" <> brainstorming_id
    )
  end

  def broadcast({:ok, %Brainstorming{} = brainstorming}, event) do
    Phoenix.PubSub.broadcast(
      Mindwendel.PubSub,
      "brainstormings:" <> brainstorming.id,
      {event, brainstorming}
    )

    {:ok, brainstorming}
  end

  @doc """
  Returns a broadcast status tuple

  ## Examples

      iex> broadcast({:ok, %Idea{}}, :idea_added)
      {:ok, %Idea{}}

  """
  def broadcast({:ok, %Idea{} = idea}, event) do
    Phoenix.PubSub.broadcast(
      Mindwendel.PubSub,
      "brainstormings:" <> idea.brainstorming_id,
      {
        event,
        idea
        |> Repo.preload([
          :link,
          :likes,
          :label,
          :idea_labels
        ])
      }
    )

    {:ok, idea}
  end

  def broadcast({:error, _reason} = error, _event), do: error
end
