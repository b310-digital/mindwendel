defmodule Mindwendel.Repo.Migrations.AddDeviceIdToLikes do
  use Ecto.Migration

  def change do
    alter table(:likes) do
      add :device_id, references(:devices, type: :uuid)
    end

    create unique_index(:likes, [:idea_id, :device_id], name: :idea_id_device_id_index)
  end
end
