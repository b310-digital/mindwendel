defmodule Mindwendel.Repo.Migrations.ChangeDevicesToUsers do
  use Ecto.Migration

  def up do
    drop constraint(:likes, "likes_device_id_fkey")
    drop constraint(:brainstorming_devices, "brainstorming_devices_device_id_fkey")
    drop constraint(:brainstorming_devices, "brainstorming_devices_brainstorming_id_fkey")
    drop constraint(:brainstorming_devices, "brainstorming_devices_pkey")
    drop constraint(:devices, "devices_pkey")
    drop index(:brainstorming_devices, [:brainstorming_id])
    drop index(:brainstorming_devices, [:device_id])
    drop index(:likes, [:idea_id, :device_id], name: :idea_id_device_id_index)

    rename table(:devices), to: table(:users)
    rename table(:brainstorming_devices), to: table(:brainstorming_users)
    rename table(:brainstorming_users), :device_id, to: :user_id
    rename table(:likes), :device_id, to: :user_id

    # modify to update fkeys / pkeys
    alter table(:users) do
      modify :id, :uuid, primary_key: true
    end

    alter table(:brainstorming_users) do
      modify :id, :uuid, primary_key: true
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      modify :brainstorming_id, references(:brainstormings, type: :uuid, on_delete: :delete_all)
    end

    create index(:brainstorming_users, [:brainstorming_id])
    create index(:brainstorming_users, [:user_id])

    alter table(:likes) do
      modify :user_id, references(:users, type: :uuid, on_delete: :delete_all)
    end

    create unique_index(:likes, [:idea_id, :user_id], name: :likes_idea_id_user_id_index)
  end

  def down do
    drop constraint(:likes, "likes_user_id_fkey")
    drop constraint(:brainstorming_users, "brainstorming_users_user_id_fkey")
    drop constraint(:brainstorming_users, "brainstorming_users_brainstorming_id_fkey")
    drop constraint(:brainstorming_users, "brainstorming_users_pkey")
    drop constraint(:users, "users_pkey")
    drop index(:brainstorming_users, [:brainstorming_id])
    drop index(:brainstorming_users, [:user_id])
    drop index(:likes, [:idea_id, :user_id], name: :likes_idea_id_user_id_index)

    rename table(:users), to: table(:devices)
    rename table(:brainstorming_users), to: table(:brainstorming_devices)
    rename table(:brainstorming_devices), :user_id, to: :device_id
    rename table(:likes), :user_id, to: :device_id

    # modify to update fkeys / pkeys
    alter table(:devices) do
      modify :id, :uuid, primary_key: true
    end

    alter table(:brainstorming_devices) do
      modify :id, :uuid, primary_key: true
      modify :device_id, references(:devices, type: :uuid, on_delete: :delete_all)
      modify :brainstorming_id, references(:brainstormings, type: :uuid, on_delete: :delete_all)
    end

    create index(:brainstorming_devices, [:brainstorming_id])
    create index(:brainstorming_devices, [:device_id])

    alter table(:likes) do
      modify :device_id, references(:devices, type: :uuid, on_delete: :delete_all)
    end

    create unique_index(:likes, [:idea_id, :device_id], name: :idea_id_device_id_index)
  end
end
