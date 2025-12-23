defmodule Mindwendel.Brainstormings do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo

  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Ideas
  alias Mindwendel.Lanes

  require Logger

  @doc """
  Returns the 3 most recent brainstormings for a a user.

  ## Examples

      iex> list_brainstormings_for(3)
      [%Brainstorming{}, ...]

  """
  def list_brainstormings_for(user_id, limit \\ 3)

  def list_brainstormings_for(nil, _) do
    []
  end

  def list_brainstormings_for(user_id, limit) do
    Repo.all(
      from brainstorming in Brainstorming,
        join: users in assoc(brainstorming, :users),
        where: users.id == ^user_id,
        order_by: [desc: brainstorming.last_accessed_at],
        limit: ^limit
    )
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

  Returns an error tuple instead of raising exceptions to handle invalid UUIDs gracefully,
  particularly important for initial brainstorming fetches that may receive spam requests.

  ## Examples

      iex> get_brainstorming("0323906b-b496-4778-ae67-1dd779d3de3c")
      %Brainstorming{ ... }

      iex> get_brainstorming("0323906b-b496-4778-ae67-1dd779d3de3c")
      {:error, :not_found}

      iex> get_brainstorming("not_a_valid_uuid_string")
      {:error, :invalid_uuid}

  """
  def get_brainstorming(id) do
    case Ecto.UUID.cast(id) do
      {:ok, id} -> get_brainstorming_with_valid_uuid(id)
      :error -> {:error, :invalid_uuid}
    end
  end

  # No uuid check here, has to be done before
  defp get_brainstorming_with_valid_uuid(id) do
    case Repo.get(Brainstorming, id) do
      nil ->
        {:error, :not_found}

      brainstorming ->
        preloaded_brainstorming =
          brainstorming
          |> Repo.preload([
            :users,
            :moderating_users,
            lanes: from(lane in Lane, order_by: lane.position_order),
            labels: from(idea_label in IdeaLabel, order_by: idea_label.position_order)
          ])

        {:ok, preloaded_brainstorming}
    end
  end

  def get_bare_brainstorming!(id) do
    Repo.get!(Brainstorming, id)
  end

  @doc """
  Gets a single brainstorming with the admin url id
  """
  def get_brainstorming_by!(%{admin_url_id: admin_url_id}) do
    Repo.get_by!(Brainstorming, admin_url_id: admin_url_id)
  end

  @doc """
  Creates a brainstorming and associates a user as creating_user, moderatoring user (also called brainstorming admin) and user.

  User hast to be persisted.

  ## Examples

    current_user =
        Mindwendel.Services.SessionService.get_current_user_id(conn)
        |> Accounts.get_or_create_user()

    {:ok, %Brainstorming{ ... }} =
      Brainstormings.create_brainstorming(current_user, %{name: "Brainstorming name"})

  """
  def create_brainstorming(%User{} = user, attrs) do
    user
    |> Ecto.build_assoc(:created_brainstormings,
      labels: Brainstorming.idea_label_factory(),
      lanes: [%Lane{position_order: 1}],
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
  def update_brainstorming(
        %Brainstorming{} = brainstorming,
        %{filter_labels_ids: filter_labels_ids} = attrs
      ) do
    unless Enum.empty?(filter_labels_ids) do
      Ideas.update_disjoint_idea_positions_for_brainstorming_by_labels(
        brainstorming.id,
        filter_labels_ids
      )
    end

    updated_brainstorming_result =
      brainstorming
      |> Brainstorming.changeset(attrs)
      |> Repo.update()

    broadcast(updated_brainstorming_result, :brainstorming_filter_updated)
  end

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
      ideas = Repo.all(from idea in Idea, where: idea.brainstorming_id == ^brainstorming.id)
      # delete_idea deletes the idea and potentially associated files
      Enum.each(ideas, fn idea -> Ideas.delete_idea(idea) end)

      case Repo.delete(brainstorming) do
        {:ok, deleted_brainstorming} ->
          deleted_brainstorming

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def empty(%Brainstorming{} = brainstorming) do
    # we only delete ideas - labels and users should be left intact:
    Repo.delete_all(from lane in Lane, where: lane.brainstorming_id == ^brainstorming.id)

    broadcast({:ok, brainstorming}, :brainstorming_updated)
  end

  @doc """
  Deletes all brainstormings, older than 30 days since last_accessed_at

  ## Examples

      iex> delete_old_brainstormings(30)
      :ok

  """
  def delete_old_brainstormings(after_days \\ 30) do
    date_time = Timex.now() |> Timex.shift(days: -1 * after_days)
    brainstormings_count = Repo.aggregate(Brainstorming, :count, :id)

    old_brainstormings_query = from b in Brainstorming, where: b.last_accessed_at < ^date_time
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
  Updates the last_accessed_at field of a brainstorming.

  ## Examples

      iex> update_last_accessed_at(brainstorming)
      %Brainstorming{last_accessed_at: ...}

  """
  def update_last_accessed_at(brainstorming) do
    Repo.update(Brainstorming.changeset_with_upated_last_accessed_at(brainstorming))
    brainstorming
  end

  @doc """
  Validates the given secret against the brainstorming. Returns true/false.

  ## Examples

      iex> validate_admin_secret(brainstorming, abc)
      false

  """
  def validate_admin_secret(brainstorming, admin_secret_id) do
    case brainstorming.admin_url_id do
      nil -> false
      admin_url_id -> admin_url_id == admin_secret_id
    end
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

  def broadcast({:ok, %Brainstorming{} = brainstorming}, :brainstorming_filter_updated = event) do
    lanes =
      Lanes.get_lanes_for_brainstorming_with_labels_filtered(brainstorming.id)

    Phoenix.PubSub.broadcast(
      Mindwendel.PubSub,
      "brainstormings:" <> brainstorming.id,
      {event, brainstorming.filter_labels_ids, lanes}
    )

    {:ok, brainstorming}
  end

  def broadcast({:ok, %Brainstorming{} = brainstorming}, event) do
    Phoenix.PubSub.broadcast(
      Mindwendel.PubSub,
      "brainstormings:" <> brainstorming.id,
      {event,
       brainstorming
       |> Repo.preload([
         :users,
         :moderating_users,
         labels: from(idea_label in IdeaLabel, order_by: idea_label.position_order)
       ])}
    )

    {:ok, brainstorming}
  end

  def broadcast({:ok, %Idea{} = idea}, event) do
    # Check if associations are loaded; if not, preload them as a fallback
    idea_with_associations =
      if idea_associations_loaded?(idea) do
        idea
      else
        preload_idea_for_broadcast(idea)
      end

    Phoenix.PubSub.broadcast(
      Mindwendel.PubSub,
      "brainstormings:" <> idea.brainstorming_id,
      {event, idea_with_associations}
    )

    {:ok, idea}
  end

  def broadcast({:ok, %Lane{} = lane}, event) do
    Phoenix.PubSub.broadcast(
      Mindwendel.PubSub,
      "brainstormings:" <> lane.brainstorming_id,
      {
        event,
        lane
        |> Repo.preload(
          ideas: [
            :link,
            :likes,
            :idea_labels,
            :files
          ]
        )
      }
    )

    {:ok, lane}
  end

  def broadcast({:ok, brainstorming_id, lanes}, :lanes_updated) do
    Phoenix.PubSub.broadcast(
      Mindwendel.PubSub,
      "brainstormings:" <> brainstorming_id,
      {
        :lanes_updated,
        lanes
      }
    )

    {:ok, brainstorming_id}
  end

  def broadcast({:error, _reason} = error, _event), do: error

  @doc """
  Preloads all associations needed for broadcasting an Idea.
  This function should be called before passing an idea to broadcast/2 to avoid N+1 queries.

  ## Examples

      iex> preload_idea_for_broadcast(%Idea{})
      %Idea{...}

  """
  def preload_idea_for_broadcast(%Idea{} = idea) do
    idea
    |> Repo.preload([
      :link,
      :likes,
      :idea_labels,
      :files,
      :comments
    ])
  end

  # Private helper to check if all required associations are loaded
  # Note: For has_one associations like :link, Ecto.assoc_loaded?/1 returns true
  # even when the value is nil (meaning no link exists), which is correct behavior
  defp idea_associations_loaded?(%Idea{} = idea) do
    Ecto.assoc_loaded?(idea.link) and
      Ecto.assoc_loaded?(idea.likes) and
      Ecto.assoc_loaded?(idea.idea_labels) and
      Ecto.assoc_loaded?(idea.files) and
      Ecto.assoc_loaded?(idea.comments)
  end
end
