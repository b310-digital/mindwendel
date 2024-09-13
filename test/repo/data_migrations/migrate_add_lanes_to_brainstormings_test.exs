defmodule Mindwendel.Repo.DataMigrations.MigrateIdealLabelsTest do
  Code.require_file("./priv/repo/data_migrations/migrate_add_lanes_to_brainstormings.exs")

  use Mindwendel.DataCase
  alias Mindwendel.Factory
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Brainstorming

  setup do
    %{brainstorming: Factory.insert!(:brainstorming)}
  end

  describe "#run/0" do
    test "migrate", %{
      brainstorming: existing_brainstorming
    } do
      MigrateIdealLabels.run()

      IO.inspect(Brainstormings.list_brainstormings)
    end
  end
end
