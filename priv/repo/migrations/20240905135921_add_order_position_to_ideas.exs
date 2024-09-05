defmodule Mindwendel.Repo.Migrations.AddOrderPositionToIdeas do
  use Ecto.Migration

  def change do
    alter table(:ideas) do
      add :order_position, :integer, default: 0
    end

    alter table(:brainstormings) do
      add :order_by, :string, default: "asc"
    end
  end
end
