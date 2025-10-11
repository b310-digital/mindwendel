defmodule Mindwendel.Brainstormings.Brainstorming do
  use Mindwendel.Schema

  import Ecto.Changeset
  use Gettext, backend: MindwendelWeb.Gettext
  alias Mindwendel.Accounts.BrainstormingModeratingUser
  alias Mindwendel.Accounts.BrainstormingUser
  alias Mindwendel.Accounts.User
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.Lane

  schema "brainstormings" do
    field :name, :string
    field :option_allow_manual_ordering, :boolean
    # credo:disable-for-next-line
    # Todo: The following line can be changed
    # `field :admin_url_id, Ecto.UUID, autogenerate: true`
    # This will automatically generate a UUID for the admin_url_id which would make
    # the method `gen_admin_url_id/2` obsolete.
    field :admin_url_id, :binary_id
    field :last_accessed_at, :utc_datetime
    field :filter_labels_ids, {:array, :binary_id}
    belongs_to :creating_user, User
    has_many :ideas, Idea
    has_many :lanes, Lane, preload_order: [asc: :position_order]
    has_many :labels, IdeaLabel
    many_to_many :users, User, join_through: BrainstormingUser
    many_to_many :moderating_users, User, join_through: BrainstormingModeratingUser

    timestamps()
  end

  @doc false
  def changeset(brainstorming, attrs) do
    brainstorming
    |> cast(attrs, [
      :name,
      :option_allow_manual_ordering,
      :filter_labels_ids
    ])
    |> validate_required([:name])
    |> cast_assoc(:labels)
    |> shorten_name
    |> gen_admin_url_id(brainstorming)
  end

  def changeset_with_upated_last_accessed_at(brainstorming) do
    brainstorming
    |> change(%{last_accessed_at: DateTime.truncate(DateTime.utc_now(), :second)})
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

  def brainstorming_available_until(brainstorming) do
    available_until =
      Timex.shift(brainstorming.last_accessed_at,
        days:
          Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]
      )

    Timex.format!(
      available_until,
      "{relative}",
      :relative
    )
  end
end
