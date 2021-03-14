defmodule Mindwendel.Repo.Migrations.AddVisibilityLinkToSettings do
  use Ecto.Migration

  def change do
    alter table("brainstormings") do
      add :option_show_link_to_settings, :boolean, default: true
    end
  end
end
