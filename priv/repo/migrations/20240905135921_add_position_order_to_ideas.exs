defmodule Mindwendel.Repo.Migrations.AddPositionOrderToIdeas do
  use Ecto.Migration

  def change do
    alter table(:ideas) do
      add :position_order, :integer, default: nil
    end
  end
end
