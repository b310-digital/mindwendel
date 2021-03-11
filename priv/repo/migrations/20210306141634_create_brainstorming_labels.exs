defmodule Mindwendel.Repo.Migrations.CreateBrainstormingLabels do
  use Ecto.Migration

  def change do
    create table(:idea_labels, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :color, :string
      add :position_order, :integer
      add :brainstorming_id, references(:brainstormings, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    create index(:idea_labels, [:brainstorming_id])
  end
end
