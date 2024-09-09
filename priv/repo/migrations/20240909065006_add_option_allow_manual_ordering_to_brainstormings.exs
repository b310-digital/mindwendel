defmodule Mindwendel.Repo.Migrations.AddOptionAllowManualOrderingToBrainstormings do
  use Ecto.Migration

  def change do
    alter table(:brainstormings) do
      add :option_allow_manual_ordering, :boolean, default: false
    end
  end
end
