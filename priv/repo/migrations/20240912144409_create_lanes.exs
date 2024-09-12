defmodule Mindwendel.Repo.Migrations.CreateLanes do
  use Ecto.Migration

  def change do
    create table(:lanes) do
      add :name, :string
      add :position_order, :integer
      add :brainstorming_id, references(:brainstormings, on_delete: :delete_all, type: :uuid)

      timestamps()
    end

    alter table(:ideas) do
      add :lane_id, references(:lanes, on_delete: :delete_all)
    end
  end
end
