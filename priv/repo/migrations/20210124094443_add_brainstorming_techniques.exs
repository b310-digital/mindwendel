defmodule Mindwendel.Repo.Migrations.AddInspirations do
  use Ecto.Migration

  def change do
    create table(:inspirations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :string, size: 1024
      add :language, :string, size: 6
      add :type, :string, size: 128

      timestamps()
    end

    create unique_index(:inspirations, [:title])
  end
end
