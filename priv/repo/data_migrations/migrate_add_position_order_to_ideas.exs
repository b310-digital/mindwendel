defmodule Mindwendel.Repo.DataMigrations.MigrateAddPositionOrderToIdeas do
  require Logger
  alias Mindwendel.Repo
  import Ecto.Query, warn: false

  defmodule Brainstorming do
    use Mindwendel.Schema

    use Gettext, backend: MindwendelWeb.Gettext
    alias Mindwendel.Brainstormings.Idea
    alias Mindwendel.Brainstormings.IdeaLabel
    alias Mindwendel.Brainstormings.Lane
    alias Mindwendel.Brainstormings.BrainstormingModeratingUser
    alias Mindwendel.Accounts.User
    alias Mindwendel.Accounts.BrainstormingUser

    schema "brainstormings" do
      field :name, :string
      field :option_show_link_to_settings, :boolean
      field :option_allow_manual_ordering, :boolean
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
  end

  defmodule Idea do
    use Mindwendel.Schema

    alias Mindwendel.Brainstormings.IdeaLabel
    alias Mindwendel.Brainstormings.IdeaIdeaLabel
    alias Mindwendel.Brainstormings.Like
    alias Mindwendel.Brainstormings.Lane
    alias Mindwendel.Brainstormings.Comment
    alias Mindwendel.Attachments.Link
    alias Mindwendel.Attachments.File
    alias Mindwendel.Accounts.User

    @label_values [:label_1, :label_2, :label_3, :label_4, :label_5]

    schema "ideas" do
      field :body, :string
      field :position_order, :integer
      field :username, :string, default: "Anonymous"
      field :deprecated_label, Ecto.Enum, source: :label, values: @label_values
      has_one :link, Link
      belongs_to :user, User
      has_many :likes, Like
      has_many :comments, Comment, preload_order: [desc: :inserted_at]
      has_many :files, File
      belongs_to :brainstorming, Brainstorming
      belongs_to :label, IdeaLabel, on_replace: :nilify
      belongs_to :lane, Lane
      many_to_many :idea_labels, IdeaLabel, join_through: IdeaIdeaLabel, on_replace: :delete

      timestamps()
    end
  end

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
