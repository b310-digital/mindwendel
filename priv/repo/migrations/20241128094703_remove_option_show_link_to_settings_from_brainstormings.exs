defmodule Mindwendel.Repo.Migrations.RemoveOptionShowLinkToSettingsFromBrainstormings do
  use Ecto.Migration

  def change do
    alter table(:brainstormings) do
      remove :option_show_link_to_settings, :boolean
    end
  end
end
