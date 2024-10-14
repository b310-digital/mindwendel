defmodule Mindwendel.Repo.Migrations.RemoveUnusedFields do
  use Ecto.Migration

  def change do
    alter table(:ideas) do
      remove :label, :text
    end
  end
end
