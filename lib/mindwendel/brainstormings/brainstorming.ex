defmodule Mindwendel.Brainstormings.Brainstorming do
  use Mindwendel.Schema

  import Ecto.Changeset
  import MindwendelWeb.Gettext
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Accounts.User
  alias Mindwendel.Accounts.BrainstormingUser

  schema "brainstormings" do
    field :name, :string
    field :option_show_link_to_settings, :boolean
    field :admin_url_id, :binary_id
    # ToDo: Please change the previous line to this one
    # It will avoids this function gen_admin_url_id/2
    # Maybe consider to write a migration for older brainstormings
    # field :admin_url_id, Ecto.UUID, autogenerate: true
    has_many :ideas, Idea
    has_many :labels, IdeaLabel
    many_to_many :users, User, join_through: BrainstormingUser

    timestamps()
  end

  @doc false
  def changeset(brainstorming, attrs) do
    brainstorming
    |> cast(attrs, [:name, :option_show_link_to_settings])
    |> validate_required([:name])
    |> cast_assoc(:labels, required: true)
    |> shorten_name
    |> gen_admin_url_id(brainstorming)
  end

  def changeset_edit(brainstorming, attrs) do
    changeset(brainstorming, attrs)
    |> cast_assoc(:labels, required: true)
  end

  defp gen_admin_url_id(changeset, brainstorming) do
    if brainstorming.admin_url_id do
      changeset
    else
      change(changeset, admin_url_id: Ecto.UUID.generate())
    end
  end

  defp shorten_name(changeset) do
    if Map.has_key?(changeset.changes, :name),
      do: change(changeset, name: String.slice(changeset.changes.name, 0..200)),
      else: changeset
  end

  def changeset_update_users(brainstorming, users) do
    brainstorming
    |> change(%{})
    |> put_assoc(:users, users)
  end

  def idea_label_factory do
    [
      %IdeaLabel{name: gettext("cyan"), color: "#0dcaf0", position_order: 0},
      %IdeaLabel{name: gettext("gray dark"), color: "#343a40", position_order: 1},
      %IdeaLabel{name: gettext("green"), color: "#198754", position_order: 2},
      %IdeaLabel{name: gettext("red"), color: "#dc3545", position_order: 3},
      %IdeaLabel{name: gettext("yellow"), color: "#ffc107", position_order: 4}
    ]
  end
end
