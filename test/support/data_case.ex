defmodule Mindwendel.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Mindwendel.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  import Mox

  using do
    quote do
      alias Mindwendel.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Mindwendel.DataCase
      import Mox
    end
  end

  # Set up Mox properly for all data tests
  setup :set_mox_from_context
  setup :verify_on_exit!
  setup :setup_ai_disabled_stub

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Mindwendel.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Mindwendel.Repo, {:shared, self()})
    end

    :ok
  end

  # Provide default AI disabled stub for all DataCase tests
  defp setup_ai_disabled_stub(_context) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> Mox.stub(:enabled?, fn -> false end)
    |> Mox.stub(:generate_ideas, fn _title, _lanes, _existing_ideas, _locale ->
      {:error, :ai_not_enabled}
    end)

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
