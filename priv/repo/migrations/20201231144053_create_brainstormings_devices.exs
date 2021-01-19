defmodule Mindwendel.Repo.Migrations.CreateBrainstormingsDevices do
  use Ecto.Migration

  def change do
    create table(:brainstorming_devices, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :brainstorming_id, references(:brainstormings, type: :uuid, on_delete: :delete_all)
      add :device_id, references(:devices, type: :uuid, on_delete: :delete_all)

      timestamps()
    end

    create index(:brainstorming_devices, [:brainstorming_id])
    create index(:brainstorming_devices, [:device_id])
  end
end
