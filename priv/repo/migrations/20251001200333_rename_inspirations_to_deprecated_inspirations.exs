defmodule Mindwendel.Repo.Migrations.RenameInspirationsToDeprecatedInspirations do
  use Ecto.Migration

  def change do
    rename table(:inspirations), to: table(:deprecated_inspirations)
  end
end
