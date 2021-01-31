defmodule Mindwendel.Accounts do
  alias Mindwendel.Repo
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Brainstorming

  # TODO: Add proper docu for methods

  def get_or_create_user(id) do
    Repo.get(User, id) ||
      case %User{id: id} |> Repo.insert() do
        {:ok, user} -> user
      end
  end

  def get_user(id) when is_nil(id) do
    nil
  end

  def get_user(id) do
    Repo.get(User, id) |> Repo.preload(:brainstormings)
  rescue
    Ecto.Query.CastError -> nil
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def merge_brainstorming_user(%Brainstorming{} = brainstorming, user_id)
      when is_nil(user_id) do
    brainstorming
  end

  def merge_brainstorming_user(%Brainstorming{} = brainstorming, user_id)
      when is_binary(user_id) do
    # TODO: Convert this to a guard
    case Ecto.UUID.dump(user_id) do
      :error -> brainstorming
      {:ok, _} -> merge_brainstorming_user(brainstorming, get_or_create_user(user_id))
    end
  end

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
end
