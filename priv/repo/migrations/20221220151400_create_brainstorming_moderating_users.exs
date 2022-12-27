defmodule Mindwendel.Repo.Migrations.CreateBrainstormingModeratingUsers do
  use Ecto.Migration

  def change do
    create table(:brainstorming_moderating_users, primary_key: false) do
      add(:brainstorming_id, references(:brainstormings, type: :uuid, on_delete: :delete_all),
        primary_key: true
      )

      add(:user_id, references(:users, type: :uuid), primary_key: true)

      timestamps()
    end

    create(index(:brainstorming_moderating_users, [:brainstorming_id]))
    create(index(:brainstorming_moderating_users, [:user_id]))

    create(
      unique_index(:brainstorming_moderating_users, [
        :brainstorming_id,
        :user_id
      ])
    )
  end
end
