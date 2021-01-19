defmodule Mindwendel.Repo.Migrations.AddAdminUuidToBrainstormings do
  use Ecto.Migration

  def change do
    alter table(:brainstormings) do
      add :admin_url_id, :uuid
    end
  end
end
