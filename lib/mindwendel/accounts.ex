defmodule Mindwendel.Accounts do
  import Ecto.Query, warn: false
  alias Mindwendel.Accounts.BrainstormingModeratingUser
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Repo

  require Logger

  @doc """
  Finds an existing user or creates a new user based on an UUID.

  Returns nil if User does not exist or any other error is raised.

  Returns nil if invalid UUID is given.

  ## Examples

      iex> get_or_create_user(uuid)
      %User{}

  """
  def get_or_create_user(id) do
    Repo.get(User, id) ||
      case %User{id: id} |> Repo.insert() do
        {:ok, user} -> user
        {:error, _changeset} -> nil
      end
  end

  @doc """
  Gets a single user based on its UUID.

  Returns nil if User does not exist or any other error is raised.

  Returns nil if invalid UUID is given.

  ## Examples

      iex> get_user("valid-uuid")
      %User{}

      iex> get_user("invalid-or-non-existing-uuid")
      nil

  """
  def get_user(id) when is_nil(id) do
    nil
  end

  def get_user(id) do
    Repo.get(User, id) |> Repo.preload([:brainstormings, :moderated_brainstormings])
  rescue
    Ecto.Query.CastError -> nil
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Adds a user as moderating user to a brainstorming.

  ## Examples

      iex> add_moderating_user(brainstorming, user)
      %Brainstorming{}

  """
  def add_moderating_user(%Brainstorming{} = brainstorming, %User{} = user) do
    if user.id in Enum.map(brainstorming.moderating_users, fn e -> e.id end) do
      {:error, :already_moderator}
    else
      %BrainstormingModeratingUser{brainstorming_id: brainstorming.id, user_id: user.id}
      |> BrainstormingModeratingUser.changeset()
      |> Repo.insert()
    end
  end

  def add_moderating_user(%Brainstorming{} = brainstorming, user_id) when is_binary(user_id) do
    case Ecto.UUID.dump(user_id) do
      :error -> {:error, :invalid_uuid}
      {:ok, _} -> add_moderating_user(brainstorming, get_or_create_user(user_id))
    end
  end

  def add_moderating_user(%Brainstorming{} = _brainstorming, user_id) when is_nil(user_id) do
    {:error, :nil_user_id}
  end

  @doc """
  Connects user to a brainstorm.

  Returns a valid brainstorming with preloaded user list.

  ## Examples

      iex> merge_brainstorming_user(brainstorming, user)
      %Brainstorming{}

  """
  def merge_brainstorming_user(%Brainstorming{} = brainstorming, %User{} = user) do
    # credo:disable-for-next-line
    unless user.id in Enum.map(brainstorming.users, fn e -> e.id end) do
      brainstorming_users = [user | brainstorming.users]

      updated_brainstorming =
        brainstorming
        |> Brainstorming.changeset_update_users(brainstorming_users)
        |> Repo.update()

      case updated_brainstorming do
        {:ok, updated_brainstorming} -> updated_brainstorming
        {:error, _} -> brainstorming
      end
    else
      brainstorming
    end
  end

  def merge_brainstorming_user(%Brainstorming{} = brainstorming, user_id)
      when is_nil(user_id) do
    brainstorming
  end

  def merge_brainstorming_user(%Brainstorming{} = brainstorming, user_id)
      when is_binary(user_id) do
    case Ecto.UUID.dump(user_id) do
      :error -> brainstorming
      {:ok, _} -> merge_brainstorming_user(brainstorming, get_or_create_user(user_id))
    end
  end

  def delete_inactive_users(after_days \\ 30) do
    date_time = Timex.now() |> Timex.shift(days: -1 * after_days)
    users_count = Repo.aggregate(User, :count, :id)

    inactive_users_query = from u in User, where: u.updated_at < ^date_time
    inactive_users_count = Repo.aggregate(inactive_users_query, :count, :id)

    Logger.info("Delete inactive users. Count: #{inactive_users_count} / #{users_count}")

    Logger.info("Starting to delete inactive users:")
    inactive_users = Repo.all(inactive_users_query)

    Enum.each(inactive_users, fn inactive_user ->
      try do
        # first, check if this user is still a moderating user somewhere. in this case,
        # we don't delete the user. we wait until the other brainstorming has been
        # deleted, and delete this user subsequently:
        unless user_has_active_brainstormings(inactive_user) do
          delete_user(inactive_user)
        end
      rescue
        e ->
          Logger.error("Error while deleting inactive user: #{inactive_user.id}")
          Logger.error(e)
      end
    end)

    Logger.info("Finished deleting old inactive users")
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def user_has_active_brainstormings(user) do
    # check if the user is still listed as creating_user, a moderating user somewhere
    # or if the user is still attached to ideas:
    still_has(user, :created_brainstormings) || still_has(user, :ideas) ||
      still_has(user, :moderated_brainstormings)
  end

  # checks if the user has an open association to assoc
  defp still_has(user, assoc) do
    user |> Ecto.assoc(assoc) |> Repo.aggregate(:count, :id) > 0
  end
end
