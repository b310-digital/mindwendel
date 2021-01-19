defmodule Mindwendel.Repo.Migrations.ChangeStringFieldsOnIdeas do
  use Ecto.Migration

  def change do
    alter table(:ideas) do
      modify :body, :string, size: 1024
    end
  end
end
