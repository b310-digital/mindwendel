defmodule Mindwendel.Repo.Migrations.CreateLanes do
  use Ecto.Migration

  def change do
    create table(:lanes, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :position_order, :integer
      add :brainstorming_id, references(:brainstormings, type: :uuid, on_delete: :delete_all)
      timestamps()
    end

    create index(:lanes, [:brainstorming_id])

    alter table(:ideas) do
      add :lane_id, references(:lanes, type: :uuid, on_delete: :delete_all)
    end

    create index(:ideas, [:brainstorming_id, :lane_id])
  end
end
