defmodule Mindwendel.Repo.Migrations.CreateBrainstormings do
  use Ecto.Migration

  def change do
    create table(:brainstormings, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string

      timestamps()
    end
  end
end
