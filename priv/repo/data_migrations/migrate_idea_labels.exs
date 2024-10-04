defmodule Mindwendel.Repo.DataMigrations.MigrateIdealLabels do
  import Ecto.Query
  import Ecto.Changeset
  use Gettext, backend: MindwendelWeb.Gettext

  alias Mindwendel.Repo

  defmodule IdeaLabel do
    use Mindwendel.Schema

    alias Mindwendel.Brainstormings.Brainstorming

    schema "idea_labels" do
      field :name, :string
      field :color, :string
      field :position_order, :integer

      belongs_to :brainstorming, Brainstorming, foreign_key: :brainstorming_id, type: :binary_id

      timestamps()
    end
  end

  defmodule Brainstorming do
    use Mindwendel.Schema
    use Gettext, backend: MindwendelWeb.Gettext

    alias Mindwendel.Repo.DataMigrations.MigrateIdealLabels.IdeaLabel

    schema "brainstormings" do
      field :name, :string
      field :option_show_link_to_settings, :boolean

      has_many :labels, IdeaLabel

      timestamps()
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

  defmodule Idea do
    use Mindwendel.Schema

    alias Mindwendel.Repo.DataMigrations.MigrateIdealLabels.Brainstorming

    @label_values [:label_1, :label_2, :label_3, :label_4, :label_5]

    schema "ideas" do
      field :deprecated_label, Ecto.Enum, source: :label, values: @label_values
      belongs_to :brainstorming, Brainstorming, foreign_key: :brainstorming_id, type: :binary_id
      belongs_to :label, IdeaLabel, foreign_key: :label_id, type: :binary_id, on_replace: :nilify

      timestamps()
    end
  end

  @deprecated_label_to_idea_label_name_mapping %{
    label_1: gettext("cyan"),
    label_2: gettext("gray dark"),
    label_3: gettext("green"),
    label_4: gettext("red"),
    label_5: gettext("yellow")
  }

  def run do
    prepare_labels_for_brainstormings()

    migrate_labels_from_ideas()
  end

  def prepare_labels_for_brainstormings do
    Repo.transaction(fn ->
      # Note: This following code works, but will load the query result into memory. This can cause problems on larger databases.
      # We should be ok considering that it is a relatively new project.
      from(Brainstorming, preload: [:labels])
      |> Repo.all()
      |> Enum.each(&migrate_labels_to_idea_labels/1)

      # This could be a better solution as it does not require to load the content query into memory.
      # Unfortunetaly, Repo.stream/1 does not allow preloads. You would need to map the data structure yourself.
      #
      # query = from(Brainstorming, preload: [:labels])
      # stream = Repo.stream(query)
      # Repo.transaction(fn() ->
      #   Enum.each(stream, &migrate_labels_to_idea_labels/1)
      # end)
    end)
  end

  def migrate_labels_from_ideas do
    Repo.transaction(fn ->
      from(Idea,
        preload: [:label, brainstorming: [:labels]],
        select: [:deprecated_label, :brainstorming_id, :label_id, :id]
      )
      |> Repo.all()
      |> Enum.each(&migrate_label_to_idea_label/1)
    end)
  end

  def deprecated_label_to_idea_label_name_for(deprecated_label) do
    @deprecated_label_to_idea_label_name_mapping[deprecated_label]
  end

  def deprecated_label_to_idea_label_name_mapping,
    do: @deprecated_label_to_idea_label_name_mapping

  defp migrate_labels_to_idea_labels(%Brainstorming{} = brainstorming) do
    new_labels = (brainstorming.labels ++ Brainstorming.idea_label_factory()) |> Enum.slice(0..4)

    change(brainstorming)
    |> put_assoc(:labels, new_labels)
    |> Repo.update()
  end

  defp migrate_label_to_idea_label(%Idea{} = idea) do
    unless idea.label do
      idea_label_name = deprecated_label_to_idea_label_name_for(idea.deprecated_label)

      idea_label =
        Enum.find(idea.brainstorming.labels, fn idea_label ->
          idea_label.name == idea_label_name
        end)

      change(idea)
      |> put_assoc(:label, idea_label)
      |> Repo.update()
    end
  end
end
