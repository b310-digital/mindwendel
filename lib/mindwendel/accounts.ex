defmodule Mindwendel.Accounts do
  alias Mindwendel.Repo
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Brainstorming

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
    Repo.get(User, id) |> Repo.preload(:brainstormings)
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
  Connects user to a brainstorm.

  Returns a valid brainstorming with preloaded user list.

  ## Examples

      iex> merge_brainstorming_user(brainstorming, user)
      %Brainstorming{}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def merge_brainstorming_user(%Brainstorming{} = brainstorming, %User{} = user) do
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
end
