defmodule Mindwendel.Repo.Migrations.AddUsernameToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :username, :string, size: 64
    end
  end
end
